#!/usr/bin/env python3
"""
全ての点検データを削除するスクリプト
Firebase Admin SDK を使用
"""

import firebase_admin
from firebase_admin import credentials, firestore

def delete_all_inspections():
    """全ての点検データを削除"""
    
    # Firebase Admin SDK の初期化
    cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
    
    # 既に初期化されている場合はスキップ
    try:
        firebase_admin.initialize_app(cred)
    except ValueError:
        pass
    
    db = firestore.client()
    
    print('🗑️ 全ての点検データを削除中...')
    
    # 点検データを500件ずつ削除
    total_deleted = 0
    
    while True:
        # 最大500件取得
        inspections = db.collection('inspections').limit(500).stream()
        
        docs = list(inspections)
        if not docs:
            break
        
        # バッチ削除
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
            total_deleted += 1
        
        batch.commit()
        print(f'🗑️ {len(docs)}件削除しました（合計: {total_deleted}件）')
    
    print(f'✅ 全ての点検データを削除しました（合計: {total_deleted}件）')

if __name__ == '__main__':
    try:
        delete_all_inspections()
    except Exception as e:
        print(f'❌ エラー: {e}')
        import traceback
        traceback.print_exc()
