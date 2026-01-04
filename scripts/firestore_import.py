#!/usr/bin/env python3
"""
Firestore CSV Import Script
機械点検項目と重機データをFirestoreにインポートする
"""

import csv
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import re

# Firebase Admin SDK初期化
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# 重機種類のマッピング
MACHINE_TYPE_MAPPING = {
    '油圧ｼｮﾍﾞﾙ': 'excavator',
    '油圧ショベル': 'excavator',
    'ブルドーザー': 'bulldozer',
    'ブルドーザ': 'bulldozer',
    '不整地運搬車': 'crawler_dump',
    'コンバインドローラー': 'combined_roller',
    '振動ﾛｰﾗｰ': 'vibration_roller',
    '振動ローラー': 'vibration_roller',
    'ハンドガイド式': 'hand_guide',
    'ハンドガイド式除草機': 'hand_guide',
}

# 日本語名の正規化マッピング
MACHINE_TYPE_NAMES = {
    'excavator': '油圧ショベル',
    'bulldozer': 'ブルドーザー',
    'crawler_dump': '不整地運搬車',
    'combined_roller': 'コンバインドローラー',
    'vibration_roller': '振動ローラー',
    'hand_guide': 'ハンドガイド式除草機',
}

def normalize_machine_type(machine_type_str):
    """機械種類を正規化してtypeIdを返す"""
    return MACHINE_TYPE_MAPPING.get(machine_type_str, None)

def generate_item_id(label):
    """点検項目名からitemIdを生成（スネークケース）"""
    # 全角を半角に変換
    label = label.replace('（', '_').replace('）', '_')
    label = label.replace('(', '_').replace(')', '_')
    label = label.replace('・', '_').replace('、', '_').replace('。', '_')
    label = label.replace(' ', '_').replace('　', '_')
    
    # 日本語をローマ字に変換（簡易版）
    # 実際のプロジェクトでは pykakasi などを使用
    replacements = {
        'ブレーキ': 'brake',
        '旋回': 'rotation',
        'ロック': 'lock',
        'クラッチ': 'clutch',
        'コントローラー': 'controller',
        '操作': 'operation',
        'レバー': 'lever',
        'ペダル': 'pedal',
        '過負荷': 'overload',
        '警報': 'alarm',
        '装置': 'device',
        'エンジン': 'engine',
        '状態': 'status',
        '走行': 'travel',
        'モータ': 'motor',
        '減速機': 'reducer',
        'メーター': 'meter',
        'ホーン': 'horn',
        '油圧': 'hydraulic',
        'シリンダー': 'cylinder',
        'ホース': 'hose',
        'フック': 'hook',
        'ワイヤ': 'wire',
        '外れ止め': 'stopper',
        'ブーム': 'boom',
        'アーム': 'arm',
        'バケット': 'bucket',
        'リンク': 'link',
        '機構': 'mechanism',
        '落下防止': 'fall_prevention',
        '水': 'water',
        '油': 'oil',
        '燃料': 'fuel',
        '漏れ': 'leak',
        'バックミラー': 'back_mirror',
        '計器': 'gauge',
        '水温': 'water_temp',
        '油温': 'oil_temp',
        '制動': 'braking',
        '駐車': 'parking',
        'ステアリング': 'steering',
        'ドーザブレード': 'dozer_blade',
        'リッパー': 'ripper',
        '履帯': 'crawler',
        '車輪': 'wheel',
        '摩耗': 'wear',
        '亀裂': 'crack',
        '損傷': 'damage',
        'タイヤ': 'tire',
        '空気圧': 'air_pressure',
        '荷役': 'cargo_handling',
        '荷台': 'loading_platform',
    }
    
    result = label
    for jp, en in replacements.items():
        result = result.replace(jp, en)
    
    # 残った日本語を削除
    result = re.sub(r'[ぁ-んァ-ヶー一-龥]', '', result)
    
    # 連続するアンダースコアを1つにまとめる
    result = re.sub(r'_+', '_', result)
    
    # 前後のアンダースコアを削除
    result = result.strip('_')
    
    # 小文字に変換
    result = result.lower()
    
    return result if result else 'item'

def import_inspection_items(csv_path):
    """点検項目CSVをFirestoreにインポート"""
    print("=" * 60)
    print("📋 点検項目のインポート開始")
    print("=" * 60)
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        items_by_type = {}
        
        for row in reader:
            machine_type = row['機械種類']
            label = row['点検項目']
            description = row['点検ポイント']
            law_required = row['法的要求事項'] == '★'
            
            type_id = normalize_machine_type(machine_type)
            if not type_id:
                print(f"⚠️ 未知の機械種類: {machine_type}")
                continue
            
            if type_id not in items_by_type:
                items_by_type[type_id] = []
            
            item_id = generate_item_id(label)
            items_by_type[type_id].append({
                'id': item_id,
                'label': label,
                'description': description,
                'lawRequired': law_required,
                'type': 'choice',
                'choices': ['good', 'bad'],
                'order': len(items_by_type[type_id]) + 1
            })
        
        # Firestoreに保存
        for type_id, items in items_by_type.items():
            # machineTypesドキュメントを作成/更新
            type_ref = db.collection('machineTypes').document(type_id)
            type_ref.set({
                'id': type_id,
                'name': MACHINE_TYPE_NAMES.get(type_id, type_id),
                'createdAt': firestore.SERVER_TIMESTAMP
            }, merge=True)
            
            print(f"\n✅ 機械種類: {MACHINE_TYPE_NAMES.get(type_id)} ({type_id})")
            print(f"   点検項目数: {len(items)}件")
            
            # itemsサブコレクションに保存
            for item in items:
                item_id = item.pop('id')
                item_ref = type_ref.collection('items').document(item_id)
                item_ref.set(item, merge=True)
            
            print(f"   ✓ {len(items)}件の点検項目を保存しました")
    
    print("\n" + "=" * 60)
    print("✅ 点検項目のインポート完了")
    print("=" * 60)

def import_machines(csv_path):
    """重機データCSVをFirestoreにインポート"""
    print("\n" + "=" * 60)
    print("🚜 重機データのインポート開始")
    print("=" * 60)
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        machines = []
        for row in reader:
            machine_type = row['重機種類']
            model = row['型式']
            unit_number = row['号機']
            
            type_id = normalize_machine_type(machine_type)
            if not type_id:
                print(f"⚠️ 未知の機械種類: {machine_type}")
                continue
            
            machines.append({
                'typeId': type_id,
                'typeName': MACHINE_TYPE_NAMES.get(type_id, machine_type),
                'model': model,
                'unitNumber': unit_number,
                'isActive': True,
                'createdAt': firestore.SERVER_TIMESTAMP
            })
        
        # Firestoreに保存
        batch = db.batch()
        for i, machine in enumerate(machines):
            doc_ref = db.collection('machines').document()
            batch.set(doc_ref, machine)
            
            if (i + 1) % 100 == 0:
                print(f"   処理中... {i + 1}/{len(machines)}件")
        
        batch.commit()
        
        print(f"\n✅ {len(machines)}台の重機を登録しました")
        
        # 種類別の集計を表示
        by_type = {}
        for machine in machines:
            type_name = machine['typeName']
            by_type[type_name] = by_type.get(type_name, 0) + 1
        
        print("\n📊 種類別台数:")
        for type_name, count in sorted(by_type.items()):
            print(f"   {type_name}: {count}台")
    
    print("\n" + "=" * 60)
    print("✅ 重機データのインポート完了")
    print("=" * 60)

if __name__ == '__main__':
    print("🚀 Firestore CSV Import Script")
    print("=" * 60)
    
    try:
        # 1. 点検項目をインポート
        import_inspection_items('/home/user/uploaded_files/機械点検項目まとめ.csv')
        
        # 2. 重機データをインポート
        import_machines('/home/user/uploaded_files/重機データ.csv')
        
        print("\n" + "=" * 60)
        print("🎉 すべてのインポートが完了しました！")
        print("=" * 60)
        
    except Exception as e:
        print(f"\n❌ エラーが発生しました: {e}")
        import traceback
        traceback.print_exc()
