#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CSVから読み込んだ機械種類に対応する点検項目テンプレートを作成
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Firebase Admin SDK初期化
print("🔧 Firebase Admin SDKを初期化中...")
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# 機械種類IDと名前のマッピング
machine_type_mapping = {
    'excavator': '油圧ショベル',
    'bulldozer': 'ブルドーザー',
    'wheel_loader': 'タイヤショベル',
    'carrier': '不整地運搬車',
    'vibration_roller': '振動ローラー',
    'combined_roller': 'コンバインドローラー',
    'tire_roller': 'タイヤローラー',
    'hand_mower': 'ハンドガイド式除草機',
    'tractor': 'トラクター',
    'shoulder_mower': '肩掛け式除草機',
    'rc_mower': 'ラジコン式除草機',
}

# 共通の点検項目テンプレート
common_inspection_items = [
    {'code': 'item_01', 'name': '車体の損傷、変形', 'category': '外観', 'isRequired': True},
    {'code': 'item_02', 'name': 'バケット、ブレード等の摩耗', 'category': '外観', 'isRequired': True},
    {'code': 'item_03', 'name': '燃料の漏れ', 'category': '燃料系統', 'isRequired': True},
    {'code': 'item_04', 'name': '作動油の漏れ', 'category': '油圧系統', 'isRequired': True},
    {'code': 'item_05', 'name': 'エンジンオイルの量', 'category': 'エンジン', 'isRequired': True},
    {'code': 'item_06', 'name': '冷却水の量', 'category': 'エンジン', 'isRequired': True},
    {'code': 'item_07', 'name': 'エアクリーナーの目詰まり', 'category': 'エンジン', 'isRequired': False},
    {'code': 'item_08', 'name': 'ブレーキの効き', 'category': '走行装置', 'isRequired': True},
    {'code': 'item_09', 'name': 'クローラー、タイヤの摩耗', 'category': '走行装置', 'isRequired': True},
    {'code': 'item_10', 'name': '警告灯、表示灯の点灯', 'category': '電装系', 'isRequired': True},
    {'code': 'item_11', 'name': 'ホーン、ランプ類の作動', 'category': '電装系', 'isRequired': True},
    {'code': 'item_12', 'name': 'ミラー、窓ガラスの汚れ', 'category': '視界', 'isRequired': False},
    {'code': 'item_13', 'name': '操作レバー、ペダルの作動', 'category': '操作系', 'isRequired': True},
    {'code': 'item_14', 'name': '異常な音、振動', 'category': '全般', 'isRequired': True},
    {'code': 'item_15', 'name': '周辺の整理整頓', 'category': '作業環境', 'isRequired': False},
]

print("\n📤 機械種類テンプレートと点検項目を作成中...\n")

for type_id, type_name in machine_type_mapping.items():
    # 1. machine_types コレクションにテンプレートを作成
    machine_type_ref = db.collection('machine_types').document(type_id)
    machine_type_data = {
        'id': type_id,
        'name': type_name,
        'description': f'{type_name}の日常点検項目',
        'isActive': True,
        'createdAt': datetime.now(),
        'updatedAt': datetime.now(),
    }
    machine_type_ref.set(machine_type_data)
    print(f"✅ 機械種類テンプレート作成: {type_name} (ID: {type_id})")
    
    # 2. inspection_items サブコレクションに点検項目を追加
    items_ref = machine_type_ref.collection('items')
    batch = db.batch()
    
    for item in common_inspection_items:
        item_ref = items_ref.document(item['code'])
        item_data = {
            **item,
            'machineTypeId': type_id,
            'createdAt': datetime.now(),
        }
        batch.set(item_ref, item_data)
    
    batch.commit()
    print(f"   📋 点検項目 {len(common_inspection_items)}件を登録")
    print()

print("✅ 全ての機械種類テンプレートと点検項目の作成が完了しました！")
print(f"\n📊 作成された機械種類: {len(machine_type_mapping)}種類")
print(f"📋 各機械種類の点検項目: {len(common_inspection_items)}項目")
