#!/usr/bin/env python3
"""Add only the rough terrain crane master. Default: read-only dry-run, ADC auth."""
import argparse
import json
import os
from pathlib import Path

MASTER = json.loads((Path(__file__).parent / 'data/rough_terrain_crane.json').read_text(encoding='utf-8'))
TYPE = MASTER['typeId']
TYPE_PATH = f'machine_types/{TYPE}'


def build_plan(existing):
    """Pure planner. Never replaces documents; conflicting managed fields abort all writes."""
    machine_docs = {p: d for p, d in existing.items() if p.startswith('machines/')}
    current_type = existing.get(TYPE_PATH)
    if current_type:
        if 'machineSortStart' not in current_type:
            raise ValueError(f'Conflict: {TYPE_PATH} lacks migration metadata')
        start = current_type['machineSortStart']
    else:
        start = max([0] + [d.get('sortOrder', 0) for d in machine_docs.values()]) + 1
    desired = {TYPE_PATH: {
        'id': TYPE, 'name': MASTER['name'], 'isActive': True,
        'description': '25t・50t共通の作業開始前点検（14項目）',
        'masterVersion': 1, 'machineSortStart': start,
    }}
    for item in MASTER['items']:
        desired[f"{TYPE_PATH}/items/{item['code']}"] = {**item, 'machineTypeId': TYPE}
    for model_index, model in enumerate(MASTER['models']):
        for unit in range(1, 16):
            path = f'machines/rtc_{model}_{unit:02}'
            desired[path] = {'type': MASTER['name'], 'typeId': TYPE, 'model': model,
                             'unitNumber': f'{unit}号機', 'isActive': True,
                             'sortOrder': start + model_index * 15 + unit - 1}
    for path, data in existing.items():
        if path.startswith('machine_types/') and '/items/' not in path:
            if data.get('name') == MASTER['name'] and path != TYPE_PATH:
                raise ValueError(f'Conflicting type name: {path}')
        if path.startswith(TYPE_PATH + '/items/') and path not in desired:
            raise ValueError(f'Unexpected crane item: {path}')
        if path.startswith('machines/'):
            if (data.get('typeId') == TYPE or data.get('type') == MASTER['name']) and path not in desired:
                raise ValueError(f'Conflicting crane machine ID: {path}; preserve and reconcile manually')
    additions = {}
    for path, data in desired.items():
        if path in existing:
            if any(existing[path].get(k) != v for k, v in data.items()):
                raise ValueError(f'Conflicting existing document: {path}')
        else:
            additions[path] = data
    return additions


def read_state(db, transaction=None):
    state = {}
    for collection in ('machines', 'machine_types', f'{TYPE_PATH}/items'):
        for doc in db.collection(collection).stream(transaction=transaction):
            state[doc.reference.path] = doc.to_dict()
    return state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True, help='Explicit Firebase project ID')
    parser.add_argument('--database', default='(default)')
    parser.add_argument('--apply', action='store_true', help='Create missing documents atomically')
    parser.add_argument('--output', type=Path, help='Write JSON execution report')
    args = parser.parse_args()
    report = {'project': args.project, 'database': args.database,
              'emulator': os.getenv('FIRESTORE_EMULATOR_HOST'),
              'mode': 'apply' if args.apply else 'dry-run',
              'targetPaths': ['machines/rtc_{25t,50t}_{01..15}', TYPE_PATH, TYPE_PATH + '/items/rtc_{01..14}']}
    try:
        from google.cloud import firestore
        # Application Default Credentials or FIRESTORE_EMULATOR_HOST; no keys in source.
        db = firestore.Client(project=args.project, database=args.database)
        if args.apply:
            @firestore.transactional
            def apply(transaction):
                additions = build_plan(read_state(db, transaction))
                for path, data in additions.items():
                    transaction.create(db.document(path), data)
                return additions
            additions = apply(db.transaction())
        else:
            additions = build_plan(read_state(db))
        report.update(status='success', addedCount=len(additions) if args.apply else 0,
                      plannedCount=len(additions), paths=list(additions),
                      expectedTotals={'templates': 1, 'items': 14, 'machines': 30})
    except Exception as error:
        report.update(status='failed', addedCount=0, error=str(error))
    result = json.dumps(report, ensure_ascii=False, indent=2)
    print(result)
    if args.output:
        args.output.write_text(result + '\n', encoding='utf-8')
    return 0 if report['status'] == 'success' else 1


if __name__ == '__main__':
    raise SystemExit(main())
