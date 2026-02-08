#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""重機データにソート順を追加"""

import csv
import firebase_admin
from firebase_admin import credentials, firestore

# Firebase Admin SDK初期化
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

print('=' * 60)
print('🔄 重機データにソート順を追加')
print('=' * 60)

# CSVファイルを読み込み
csv_file = '/home/user/uploaded_files/重機データ.csv'
machines_data = []

with open(csv_file, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for idx, row in enumerate(reader, start=1):
        machine_type = row['重機種類'].strip()
        model = row['型式'].strip()
        unit_number = row['号機'].strip()
        
        machines_data.append({
            'type': machine_type,
            'model': model,
            'unitNumber': unit_number,
            'sortOrder': idx  # CSV行番号をソート順として使用
        })

print(f'📦 CSV読み込み完了: {len(machines_data)}件')

# Firestoreの重機データを取得してソート順を更新
machines_ref = db.collection('machines')
machines = machines_ref.stream()

updated_count = 0
not_found_count = 0

for machine in machines:
    data = machine.to_dict()
    machine_type = data.get('type', '')
    model = data.get('model', '')
    unit_number = data.get('unitNumber', '')
    
    # CSVデータから該当する重機を検索
    matching_machine = None
    for csv_machine in machines_data:
        if (csv_machine['type'] == machine_type and 
            csv_machine['model'] == model and 
            csv_machine['unitNumber'] == unit_number):
            matching_machine = csv_machine
            break
    
    if matching_machine:
        # ソート順を更新
        machines_ref.document(machine.id).update({
            'sortOrder': matching_machine['sortOrder']
        })
        updated_count += 1
        print(f'✅ 更新: {machine_type} {model} {unit_number} → sortOrder: {matching_machine["sortOrder"]}')
    else:
        not_found_count += 1
        print(f'⚠️  CSV未登録: {machine_type} {model} {unit_number}')

print('\n' + '=' * 60)
print(f'✅ ソート順更新完了')
print(f'   更新件数: {updated_count}件')
print(f'   CSV未登録: {not_found_count}件')
print('=' * 60)
