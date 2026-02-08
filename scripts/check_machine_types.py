#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import firebase_admin
from firebase_admin import credentials, firestore

# Firebase Admin SDK初期化
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

print("📋 既存の機械種類テンプレート（machine_types）を確認中...\n")

machine_types_ref = db.collection('machine_types')
docs = machine_types_ref.get()

if not docs:
    print("⚠️ machine_types コレクションが空です")
else:
    print(f"✅ {len(docs)}件の機械種類テンプレートが見つかりました:\n")
    for doc in docs:
        data = doc.data()
        print(f"ID: {doc.id}")
        print(f"  名前: {data.get('name', 'N/A')}")
        print(f"  説明: {data.get('description', 'N/A')}")
        print()
