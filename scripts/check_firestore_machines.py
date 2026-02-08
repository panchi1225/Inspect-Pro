#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Firestoreの重機データを確認"""

import firebase_admin
from firebase_admin import credentials, firestore

# Firebase Admin SDK初期化
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

print('=' * 60)
print('🔍 Firestore重機データ確認')
print('=' * 60)

# machinesコレクションを取得
machines_ref = db.collection('machines')
machines = machines_ref.stream()

count = 0
sample_shown = 0

for machine in machines:
    count += 1
    data = machine.to_dict()
    
    # 最初の3件をサンプル表示
    if sample_shown < 3:
        print(f'\n📦 サンプル重機 #{sample_shown + 1}:')
        print(f'   ID: {machine.id}')
        print(f'   フィールド一覧:')
        for key, value in data.items():
            print(f'      {key}: {value}')
        sample_shown += 1

print(f'\n' + '=' * 60)
print(f'✅ 合計重機数: {count}台')
print('=' * 60)

# 重機種類の統計
print('\n📊 重機種類別の台数:')
machines = machines_ref.stream()
type_counts = {}

for machine in machines:
    data = machine.to_dict()
    # typeNameまたはtypeフィールドを確認
    machine_type = data.get('typeName') or data.get('type') or '不明'
    type_counts[machine_type] = type_counts.get(machine_type, 0) + 1

for machine_type, count in sorted(type_counts.items()):
    print(f'   {machine_type}: {count}台')

print('\n' + '=' * 60)
