#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CSVファイルから機械データをFirestoreにインポートするスクリプト
"""

import csv
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Firebase Admin SDK初期化
print("🔧 Firebase Admin SDKを初期化中...")
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# 既存の機械データを全て削除
print("\n🗑️ 既存の機械データを削除中...")
machines_ref = db.collection('machines')
batch_size = 500

while True:
    docs = machines_ref.limit(batch_size).get()
    if not docs:
        break
    
    batch = db.batch()
    deleted_count = 0
    for doc in docs:
        batch.delete(doc.reference)
        deleted_count += 1
    batch.commit()
    
    print(f"   {deleted_count}件削除しました")
    
    if len(docs) < batch_size:
        break

print("✅ 既存データの削除完了\n")

# CSVファイルから機械データを読み込み
csv_file_path = '/home/user/uploaded_files/重機データ.csv'
print(f"📄 CSVファイルを読み込み中: {csv_file_path}")

machines = []
machine_types = set()  # 重機種類の一覧を取得

with open(csv_file_path, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        machine_type = row['重機種類'].strip()
        model = row['型式'].strip()
        unit_number = row['号機'].strip()
        
        # 重機種類IDを生成（油圧ショベル → excavator）
        type_id_map = {
            '油圧ショベル': 'excavator',
            'ブルドーザー': 'bulldozer',
            'タイヤショベル': 'wheel_loader',
            '不整地運搬車': 'carrier',
            '振動ローラー': 'vibration_roller',
            'コンバインドローラー': 'combined_roller',
            'タイヤローラー': 'tire_roller',
            'ハンドガイド式除草機': 'hand_mower',
            'トラクター': 'tractor',
            '肩掛け式除草機': 'shoulder_mower',
            'ラジコン式除草機': 'rc_mower',
        }
        
        type_id = type_id_map.get(machine_type, machine_type.lower().replace(' ', '_'))
        machine_types.add(machine_type)
        
        machine = {
            'type': machine_type,
            'typeId': type_id,
            'model': model,
            'unitNumber': unit_number,
            'isActive': True,
            'createdAt': datetime.now(),
            'updatedAt': datetime.now(),
        }
        
        machines.append(machine)

print(f"✅ {len(machines)}件の機械データを読み込みました")
print(f"📊 機械種類: {', '.join(sorted(machine_types))}\n")

# Firestoreに一括登録
print("📤 Firestoreに機械データを登録中...")
batch = db.batch()
registered_count = 0

for machine in machines:
    doc_ref = machines_ref.document()
    batch.set(doc_ref, machine)
    registered_count += 1
    
    # 500件ごとにバッチをコミット
    if registered_count % 500 == 0:
        batch.commit()
        print(f"   {registered_count}件登録しました")
        batch = db.batch()

# 残りをコミット
if registered_count % 500 != 0:
    batch.commit()
    print(f"   {registered_count}件登録しました")

print(f"\n✅ 機械データのインポート完了！")
print(f"📊 合計 {registered_count}件の機械を登録しました")
print(f"\n🎯 登録された機械種類:")
for machine_type in sorted(machine_types):
    count = sum(1 for m in machines if m['type'] == machine_type)
    print(f"   - {machine_type}: {count}台")
