"""Optional integration: FIRESTORE_EMULATOR_HOST=127.0.0.1:8787.

Use an empty, disposable emulator project demo-inspect-pro-rtc only.
Never run against production. No cleanup/delete is performed by this test.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest


@unittest.skipUnless(os.getenv('FIRESTORE_EMULATOR_HOST'), 'Firestore Emulator required')
class EmulatorMigrationTest(unittest.TestCase):
    def test_dry_run_apply_repeat_and_conflict(self):
        from google.cloud import firestore
        from add_rough_terrain_crane import TYPE_PATH, read_state

        project = 'demo-inspect-pro-rtc'
        db = firestore.Client(project=project)
        self.assertEqual(read_state(db), {}, 'Use a fresh disposable emulator project')
        old = {
            'machines/legacy-machine': {'type': '油圧ショベル', 'typeId': 'excavator', 'model': '既存型式',
                                        'unitNumber': '1号機', 'isActive': True, 'sortOrder': 77},
            'machine_types/excavator': {'name': '油圧ショベル'},
            'machine_types/excavator/items/item_01': {'name': '既存項目', 'checkpoint': '既存ポイント'},
            'inspections/legacy-record': {'machineId': 'legacy-machine', 'date': '2024-10-01',
                                          'results': {'item_01': {'isGood': False, 'memo': '既存メモ'}}},
        }
        for path, data in old.items():
            db.document(path).create(data)

        def execute(apply=False):
            command = [sys.executable, str(Path(__file__).with_name('add_rough_terrain_crane.py')),
                       '--project', project]
            if apply:
                command.append('--apply')
            result = subprocess.run(command, text=True, encoding='utf-8', capture_output=True)
            report = json.loads(result.stdout)
            print(json.dumps(report, ensure_ascii=False), flush=True)
            return result.returncode, report

        code, dry = execute()
        self.assertEqual(code, 0)
        self.assertEqual(dry['plannedCount'], 45)
        self.assertEqual(len(read_state(db)), 2)
        code, first = execute(True)
        self.assertEqual(code, 0)
        self.assertEqual(first['addedCount'], 45)
        before_repeat = read_state(db)
        code, repeated = execute(True)
        self.assertEqual(code, 0)
        self.assertEqual(repeated['addedCount'], 0)
        self.assertEqual(read_state(db), before_repeat)
        self.assertEqual(len(list(db.collection(f'{TYPE_PATH}/items').stream())), 14)
        machines = [d.to_dict() for d in db.collection('machines').stream() if d.to_dict().get('typeId') == 'rough_terrain_crane']
        self.assertEqual(len(machines), 30)
        for model in ('25t', '50t'):
            units = sorted((m for m in machines if m['model'] == model), key=lambda m: m['sortOrder'])
            self.assertEqual([m['unitNumber'] for m in units], [f'{i}号機' for i in range(1, 16)])
        for path, data in old.items():
            self.assertEqual(db.document(path).get().to_dict(), data)

        db.document(f'{TYPE_PATH}/items/rtc_06').update({'checkpoint': '既存の変更内容'})
        before_conflict = read_state(db)
        code, conflict = execute(True)
        self.assertEqual(code, 1)
        self.assertEqual(conflict['addedCount'], 0)
        self.assertEqual(read_state(db), before_conflict)


if __name__ == '__main__':
    unittest.main()
