#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import firebase_admin
from firebase_admin import credentials, firestore

# Firebase Admin SDK初期化
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

print("=" * 80)
print("📊 点検項目インポート結果の確認")
print("=" * 80)

machine_types_ref = db.collection('machine_types')
machine_types = list(machine_types_ref.stream())

print(f"\n✅ 合計: {len(machine_types)}種類の機械\n")

for mt in machine_types:
    data = mt.to_dict()
    items = list(mt.reference.collection('items').stream())
    
    print(f"\n📋 {data.get('name', 'N/A')} (ID: {mt.id})")
    print(f"   点検項目: {len(items)}件")
    
    # 法的要求事項の数を確認
    legal_items = sum(1 for item in items if item.to_dict().get('isRequired', False))
    print(f"   法的要求事項（★）: {legal_items}件")
    
    # サンプルとして最初の3項目を表示
    print(f"   サンプル項目:")
    for idx, item in enumerate(items[:3], 1):
        item_data = item.to_dict()
        legal_mark = "★" if item_data.get('isRequired') else ""
        print(f"      {idx}. {legal_mark} {item_data.get('name', 'N/A')}")
        if item_data.get('checkpoint'):
            print(f"         → {item_data.get('checkpoint')}")

print("\n" + "=" * 80)
print("✅ 点検項目のインポート完了！アプリで確認してください")
print("=" * 80)
