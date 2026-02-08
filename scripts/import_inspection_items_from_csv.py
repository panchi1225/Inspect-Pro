#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CSVファイルから点検項目をFirestoreにインポートするスクリプト
既存の点検項目を削除して、新しいデータで置き換える
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

# 機械種類名とIDのマッピング
machine_type_mapping = {
    '油圧ｼｮﾍﾞﾙ': 'excavator',
    'ブルドーザー': 'bulldozer',
    'タイヤショベル': 'wheel_loader',
    '不整地運搬車': 'carrier',
    'コンバインドローラー': 'combined_roller',
    '振動ﾛｰﾗｰ': 'vibration_roller',
    'タイヤローラー': 'tire_roller',
    'トラクター': 'tractor',
    'ハンドガイド式除草機': 'hand_mower',
    'ハンドガイド式': 'hand_mower',  # CSVのバリエーション対応
    '肩掛け式除草機': 'shoulder_mower',
    'ラジコン式除草機': 'rc_mower',
}

# CSVファイルから点検項目を読み込み
csv_file_path = '/home/user/uploaded_files/0119_機械点検項目まとめ.csv'
print(f"📄 CSVファイルを読み込み中: {csv_file_path}\n")

# 機械種類ごとに点検項目を整理
inspection_items_by_type = {}

with open(csv_file_path, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        machine_type_name = row['機械種類'].strip()
        item_name = row['点検項目'].strip()
        checkpoint = row['点検ポイント'].strip()
        is_legal = row['法的要求事項'].strip() == '★'
        legal_basis = row['根拠法令'].strip() if row['根拠法令'].strip() else None
        
        # 機械種類IDを取得
        type_id = machine_type_mapping.get(machine_type_name)
        if not type_id:
            print(f"⚠️ 未知の機械種類: {machine_type_name}")
            continue
        
        if type_id not in inspection_items_by_type:
            inspection_items_by_type[type_id] = []
        
        # 点検項目を追加
        item = {
            'name': item_name,
            'checkpoint': checkpoint,
            'isLegal': is_legal,
            'legalBasis': legal_basis,
        }
        inspection_items_by_type[type_id].append(item)

print(f"✅ {len(inspection_items_by_type)}種類の機械の点検項目を読み込みました\n")
for type_id, items in inspection_items_by_type.items():
    print(f"   {type_id}: {len(items)}項目")
print()

# 既存の点検項目を削除して、新しいデータで置き換え
print("🔄 Firestoreの点検項目を更新中...\n")

for type_id, items in inspection_items_by_type.items():
    machine_type_ref = db.collection('machine_types').document(type_id)
    
    # 機械種類テンプレートが存在するか確認
    if not machine_type_ref.get().exists:
        print(f"⚠️ 機械種類テンプレートが見つかりません: {type_id}")
        continue
    
    # 既存の点検項目を削除
    items_ref = machine_type_ref.collection('items')
    existing_items = items_ref.stream()
    deleted_count = 0
    
    batch = db.batch()
    for doc in existing_items:
        batch.delete(doc.reference)
        deleted_count += 1
    batch.commit()
    
    if deleted_count > 0:
        print(f"   🗑️ {type_id}: 既存の{deleted_count}項目を削除")
    
    # 新しい点検項目を登録
    batch = db.batch()
    for idx, item in enumerate(items, start=1):
        item_code = f"item_{idx:02d}"
        item_ref = items_ref.document(item_code)
        
        item_data = {
            'code': item_code,
            'name': item['name'],
            'checkpoint': item['checkpoint'],
            'isRequired': item['isLegal'],  # 法的要求事項 = 必須項目
            'legalBasis': item['legalBasis'],
            'machineTypeId': type_id,
            'createdAt': datetime.now(),
        }
        batch.set(item_ref, item_data)
    
    batch.commit()
    print(f"   ✅ {type_id}: 新しい{len(items)}項目を登録")

print("\n✅ 全ての点検項目の更新が完了しました！")
print(f"\n📊 更新された機械種類: {len(inspection_items_by_type)}種類")
