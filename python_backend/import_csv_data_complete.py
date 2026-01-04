#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CSV点検者データの完全インポートスクリプト
すべての既存点検者データを削除し、CSVのデータのみを反映
"""
import sqlite3
import csv
from datetime import datetime

# データベースパス
DB_PATH = '/home/user/flutter_app/python_backend/inspection_db.sqlite'
CSV_PATH = '/home/user/uploaded_files/点検者.csv'

def import_inspectors_from_csv():
    """CSVから点検者データを完全インポート（既存データ全削除）"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        # 【重要】既存の全点検者データを削除
        cursor.execute('DELETE FROM master_data WHERE data_type = "inspector"')
        deleted_count = cursor.rowcount
        print(f'🗑️  既存点検者データ削除: {deleted_count}件')
        
        # CSVから点検者データを読み込み
        with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            inspectors = []
            for row in reader:
                inspector_name = row['点検者'].strip()
                if inspector_name:
                    inspectors.append(inspector_name)
        
        # CSVデータを順序を保持して挿入
        now = datetime.now().isoformat()
        for i, inspector_name in enumerate(inspectors, start=1):
            cursor.execute(
                'INSERT INTO master_data (data_type, name, created_at, sort_order) VALUES (?, ?, ?, ?)',
                ('inspector', inspector_name, now, i)
            )
        
        conn.commit()
        
        # 登録結果確認
        cursor.execute('SELECT name, sort_order FROM master_data WHERE data_type = "inspector" ORDER BY sort_order')
        registered_inspectors = cursor.fetchall()
        
        print(f'✅ CSVから{len(inspectors)}名の点検者を登録しました')
        print('\n【登録された点検者一覧】')
        for name, order in registered_inspectors:
            print(f'  {order:2d}. {name}')
        
        return len(inspectors)
        
    except Exception as e:
        print(f'❌ インポートエラー: {e}')
        conn.rollback()
        raise
    finally:
        conn.close()

if __name__ == '__main__':
    print('=' * 60)
    print('🔄 CSVから点検者データを完全インポート')
    print('=' * 60)
    count = import_inspectors_from_csv()
    print(f'\n✅ インポート完了: {count}名')
