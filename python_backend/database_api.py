#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Database API - クラウド同期用のデータベースAPI
SQLiteを使用して複数端末間でデータを共有
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3
import json
import os
from datetime import datetime
import threading

app = Flask(__name__)
CORS(app)

# データベースファイルのパス
DB_PATH = '/home/user/flutter_app/python_backend/inspection_db.sqlite'

# スレッドセーフなデータベース接続
db_lock = threading.Lock()

def init_database():
    """データベースの初期化"""
    with db_lock:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # 点検記録テーブル
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS inspection_records (
                id TEXT PRIMARY KEY,
                machine_id TEXT NOT NULL,
                site_name TEXT,
                inspector_name TEXT NOT NULL,
                inspection_date TEXT NOT NULL,
                results TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        ''')
        
        # 重機マスタテーブル
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS machines (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                model TEXT NOT NULL,
                unit_number TEXT NOT NULL,
                data TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        ''')
        
        conn.commit()
        conn.close()
        print('✅ Database initialized')

# アプリ起動時にデータベース初期化
init_database()

def get_db():
    """データベース接続を取得"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

# ============================================================
# 点検記録API
# ============================================================

@app.route('/api/records', methods=['GET'])
def get_all_records():
    """すべての点検記録を取得"""
    try:
        with db_lock:
            conn = get_db()
            cursor = conn.cursor()
            cursor.execute('''
                SELECT * FROM inspection_records 
                ORDER BY inspection_date DESC, created_at DESC
            ''')
            rows = cursor.fetchall()
            conn.close()
        
        records = []
        for row in rows:
            record = {
                'id': row['id'],
                'machineId': row['machine_id'],
                'siteName': row['site_name'],
                'inspectorName': row['inspector_name'],
                'inspectionDate': row['inspection_date'],
                'results': json.loads(row['results']),
                'createdAt': row['created_at'],
                'updatedAt': row['updated_at']
            }
            records.append(record)
        
        return jsonify({'records': records, 'count': len(records)}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/records/<record_id>', methods=['GET'])
def get_record(record_id):
    """特定の点検記録を取得"""
    try:
        with db_lock:
            conn = get_db()
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM inspection_records WHERE id = ?', (record_id,))
            row = cursor.fetchone()
            conn.close()
        
        if not row:
            return jsonify({'error': 'Record not found'}), 404
        
        record = {
            'id': row['id'],
            'machineId': row['machine_id'],
            'siteName': row['site_name'],
            'inspectorName': row['inspector_name'],
            'inspectionDate': row['inspection_date'],
            'results': json.loads(row['results']),
            'createdAt': row['created_at'],
            'updatedAt': row['updated_at']
        }
        
        return jsonify(record), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/records', methods=['POST'])
def create_record():
    """点検記録を作成"""
    try:
        data = request.get_json()
        
        # 必須フィールドのチェック
        required_fields = ['id', 'machineId', 'inspectorName', 'inspectionDate', 'results']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        now = datetime.now().isoformat()
        
        with db_lock:
            conn = get_db()
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO inspection_records 
                (id, machine_id, site_name, inspector_name, inspection_date, results, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                data['id'],
                data['machineId'],
                data.get('siteName', ''),
                data['inspectorName'],
                data['inspectionDate'],
                json.dumps(data['results'], ensure_ascii=False),
                now,
                now
            ))
            conn.commit()
            conn.close()
        
        return jsonify({'message': 'Record created', 'id': data['id']}), 201
        
    except sqlite3.IntegrityError:
        return jsonify({'error': 'Record already exists'}), 409
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/records/<record_id>', methods=['PUT'])
def update_record(record_id):
    """点検記録を更新"""
    try:
        data = request.get_json()
        now = datetime.now().isoformat()
        
        with db_lock:
            conn = get_db()
            cursor = conn.cursor()
            
            # 既存レコードの確認
            cursor.execute('SELECT * FROM inspection_records WHERE id = ?', (record_id,))
            if not cursor.fetchone():
                conn.close()
                return jsonify({'error': 'Record not found'}), 404
            
            # 更新
            cursor.execute('''
                UPDATE inspection_records 
                SET machine_id = ?, site_name = ?, inspector_name = ?, 
                    inspection_date = ?, results = ?, updated_at = ?
                WHERE id = ?
            ''', (
                data.get('machineId'),
                data.get('siteName', ''),
                data.get('inspectorName'),
                data.get('inspectionDate'),
                json.dumps(data.get('results', {}), ensure_ascii=False),
                now,
                record_id
            ))
            conn.commit()
            conn.close()
        
        return jsonify({'message': 'Record updated', 'id': record_id}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/records/<record_id>', methods=['DELETE'])
def delete_record(record_id):
    """点検記録を削除"""
    try:
        with db_lock:
            conn = get_db()
            cursor = conn.cursor()
            cursor.execute('DELETE FROM inspection_records WHERE id = ?', (record_id,))
            deleted_count = cursor.rowcount
            conn.commit()
            conn.close()
        
        if deleted_count == 0:
            return jsonify({'error': 'Record not found'}), 404
        
        return jsonify({'message': 'Record deleted', 'id': record_id}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ============================================================
# 同期API
# ============================================================

@app.route('/api/sync', methods=['POST'])
def sync_data():
    """データ同期（ローカルとクラウドのマージ）"""
    try:
        data = request.get_json()
        local_records = data.get('records', [])
        
        with db_lock:
            conn = get_db()
            cursor = conn.cursor()
            
            sync_result = {
                'created': 0,
                'updated': 0,
                'conflicts': 0
            }
            
            for record in local_records:
                # 既存レコードのチェック
                cursor.execute('SELECT updated_at FROM inspection_records WHERE id = ?', (record['id'],))
                row = cursor.fetchone()
                
                now = datetime.now().isoformat()
                
                if not row:
                    # 新規作成
                    cursor.execute('''
                        INSERT INTO inspection_records 
                        (id, machine_id, site_name, inspector_name, inspection_date, results, created_at, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        record['id'],
                        record['machineId'],
                        record.get('siteName', ''),
                        record['inspectorName'],
                        record['inspectionDate'],
                        json.dumps(record['results'], ensure_ascii=False),
                        record.get('createdAt', now),
                        record.get('updatedAt', now)
                    ))
                    sync_result['created'] += 1
                else:
                    # 更新日時で比較
                    server_updated_at = row['updated_at']
                    local_updated_at = record.get('updatedAt', '')
                    
                    if local_updated_at > server_updated_at:
                        # ローカルが新しい場合のみ更新
                        cursor.execute('''
                            UPDATE inspection_records 
                            SET machine_id = ?, site_name = ?, inspector_name = ?, 
                                inspection_date = ?, results = ?, updated_at = ?
                            WHERE id = ?
                        ''', (
                            record['machineId'],
                            record.get('siteName', ''),
                            record['inspectorName'],
                            record['inspectionDate'],
                            json.dumps(record['results'], ensure_ascii=False),
                            local_updated_at,
                            record['id']
                        ))
                        sync_result['updated'] += 1
                    else:
                        sync_result['conflicts'] += 1
            
            conn.commit()
            
            # 全レコードを返す
            cursor.execute('SELECT * FROM inspection_records ORDER BY inspection_date DESC')
            rows = cursor.fetchall()
            conn.close()
        
        records = []
        for row in rows:
            record = {
                'id': row['id'],
                'machineId': row['machine_id'],
                'siteName': row['site_name'],
                'inspectorName': row['inspector_name'],
                'inspectionDate': row['inspection_date'],
                'results': json.loads(row['results']),
                'createdAt': row['created_at'],
                'updatedAt': row['updated_at']
            }
            records.append(record)
        
        return jsonify({
            'message': 'Sync completed',
            'result': sync_result,
            'records': records
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5061, debug=False)
