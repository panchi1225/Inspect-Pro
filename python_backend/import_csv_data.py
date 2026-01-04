#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CSVデータをmaster_dataテーブルにインポート
"""

import sqlite3
import csv
from datetime import datetime

DB_PATH = '/home/user/flutter_app/python_backend/inspection_db.sqlite'
CSV_PATH = '/home/user/uploaded_files/点検者.csv'

def import_inspectors():
    """点検者CSVをインポート"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 既存の点検者データを削除
    cursor.execute('DELETE FROM master_data WHERE data_type = "inspector"')
    print('🗑️  既存の点検者データを削除')
    
    # CSVを読み込んで追加（順序番号付き）
    imported_count = 0
    now = datetime.now().isoformat()
    sort_order = 1
    
    with open(CSV_PATH, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            inspector_name = row['点検者'].strip()
            if inspector_name:
                cursor.execute(
                    'INSERT OR IGNORE INTO master_data (data_type, name, created_at, sort_order) VALUES (?, ?, ?, ?)',
                    ('inspector', inspector_name, now, sort_order)
                )
                imported_count += 1
                sort_order += 1
    
    conn.commit()
    conn.close()
    
    print(f'✅ {imported_count}件の点検者をインポートしました')
    
    # 確認
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT name FROM master_data WHERE data_type = "inspector" ORDER BY name')
    inspectors = [row[0] for row in cursor.fetchall()]
    conn.close()
    
    print(f'\n📋 登録済み点検者一覧 ({len(inspectors)}件):')
    for inspector in inspectors:
        print(f'  - {inspector}')

if __name__ == '__main__':
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    print('📥 点検者データインポート')
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    import_inspectors()
    print('\n✅ インポート完了')
