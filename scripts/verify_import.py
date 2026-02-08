#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import firebase_admin
from firebase_admin import credentials, firestore

# Firebase Admin SDK初期化
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

print("=" * 60)
print("📊 機械データインポート結果の確認")
print("=" * 60)

# 1. 機械データの確認
print("\n1️⃣ 登録された機械 (machines コレクション):\n")
machines_ref = db.collection('machines')
machines = machines_ref.stream()

machine_count_by_type = {}
total_count = 0
for machine in machines:
    data = machine.to_dict()
    machine_type = data.get('type', 'Unknown')
    machine_count_by_type[machine_type] = machine_count_by_type.get(machine_type, 0) + 1
    total_count += 1

print(f"✅ 合計: {total_count}台\n")
for machine_type, count in sorted(machine_count_by_type.items()):
    print(f"   {machine_type}: {count}台")

# 2. 機械種類テンプレートの確認
print("\n\n2️⃣ 機械種類テンプレート (machine_types コレクション):\n")
machine_types_ref = db.collection('machine_types')
machine_types = list(machine_types_ref.stream())

print(f"✅ 合計: {len(machine_types)}種類\n")
for mt in machine_types:
    data = mt.to_dict()
    # 点検項目の数を確認
    items = list(mt.reference.collection('items').stream())
    print(f"   {data.get('name', 'N/A')} (ID: {mt.id})")
    print(f"      点検項目: {len(items)}件")

print("\n" + "=" * 60)
print("✅ インポート完了！アプリで確認してください")
print("=" * 60)
