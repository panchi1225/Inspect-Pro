#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Unified Server - Flutter Web + Excel API
FlutterアプリとExcel APIを同一オリジンで提供する統合サーバー
"""

from flask import Flask, request, jsonify, send_file, send_from_directory
from flask_cors import CORS
import json
import os
import tempfile
import sqlite3
import threading
from datetime import datetime
from excel_generator_advanced import create_inspection_report

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

# Flutter Web静的ファイルのパス
FLUTTER_WEB_DIR = '/home/user/flutter_app/build/web'

# ============================================================
# Excel API エンドポイント
# ============================================================

@app.route('/api/generate-excel', methods=['POST', 'OPTIONS'])
def generate_excel():
    """
    Excel生成API
    
    OPTIONS: プリフライトリクエスト対応
    POST: Excel生成
    """
    if request.method == 'OPTIONS':
        # CORSプリフライトリクエストに対応
        response = jsonify({'status': 'ok'})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS')
        return response, 200
    
    try:
        # リクエストデータを取得
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'リクエストボディが空です'}), 400
        
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        print('📊 Excel生成APIリクエスト受信')
        print(f'   重機: {data.get("machine_model")} {data.get("machine_unit")}')
        print(f'   対象月: {data.get("year")}年{data.get("month")}月')
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        
        # 一時ファイルパスを生成
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'inspection_report_{timestamp}.xlsx'
        output_path = os.path.join(tempfile.gettempdir(), filename)
        
        # Excel生成
        create_inspection_report(data, output_path)
        
        # ファイルが生成されたか確認
        if not os.path.exists(output_path):
            return jsonify({'error': 'Excelファイルの生成に失敗しました'}), 500
        
        print(f'✅ Excel生成成功: {output_path}')
        
        # ダウンロード用ファイル名
        machine_info = f"{data.get('machine_model', '重機')}_{data.get('machine_unit', '')}".replace('/', '_').replace('（', '').replace('）', '')
        download_filename = f"点検表_{machine_info}_{data.get('year')}年{data.get('month')}月.xlsx"
        
        # Excelファイルを返す
        response = send_file(
            output_path,
            mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            as_attachment=True,
            download_name=download_filename
        )
        
        # CORSヘッダーを追加
        response.headers.add('Access-Control-Allow-Origin', '*')
        
        return response
        
    except Exception as e:
        print(f'❌ Excel生成APIエラー: {e}')
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    """ヘルスチェックエンドポイント"""
    return jsonify({'status': 'ok', 'message': 'Unified Server is running'}), 200

# ============================================================
# データベースAPI - 点検記録の同期
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
        print(f'❌ 点検記録取得エラー: {e}')
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
        print(f'❌ 点検記録取得エラー: {e}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/records', methods=['POST', 'OPTIONS'])
def create_record():
    """点検記録を作成"""
    if request.method == 'OPTIONS':
        response = jsonify({'status': 'ok'})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS')
        return response, 200
    
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
        
        print(f'✅ 点検記録作成: {data["id"]}')
        return jsonify({'message': 'Record created', 'id': data['id']}), 201
        
    except sqlite3.IntegrityError:
        return jsonify({'error': 'Record already exists'}), 409
    except Exception as e:
        print(f'❌ 点検記録作成エラー: {e}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/records/<record_id>', methods=['PUT', 'OPTIONS'])
def update_record(record_id):
    """点検記録を更新"""
    if request.method == 'OPTIONS':
        response = jsonify({'status': 'ok'})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        response.headers.add('Access-Control-Allow-Methods', 'PUT, OPTIONS')
        return response, 200
    
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
        
        print(f'✅ 点検記録更新: {record_id}')
        return jsonify({'message': 'Record updated', 'id': record_id}), 200
        
    except Exception as e:
        print(f'❌ 点検記録更新エラー: {e}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/records/<record_id>', methods=['DELETE', 'OPTIONS'])
def delete_record(record_id):
    """点検記録を削除"""
    if request.method == 'OPTIONS':
        response = jsonify({'status': 'ok'})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        response.headers.add('Access-Control-Allow-Methods', 'DELETE, OPTIONS')
        return response, 200
    
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
        
        print(f'✅ 点検記録削除: {record_id}')
        return jsonify({'message': 'Record deleted', 'id': record_id}), 200
        
    except Exception as e:
        print(f'❌ 点検記録削除エラー: {e}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/sync', methods=['POST', 'OPTIONS'])
def sync_data():
    """データ同期（ローカルとクラウドのマージ）"""
    if request.method == 'OPTIONS':
        response = jsonify({'status': 'ok'})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS')
        return response, 200
    
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
        
        print(f'✅ データ同期完了: 作成={sync_result["created"]}, 更新={sync_result["updated"]}, 競合={sync_result["conflicts"]}')
        
        return jsonify({
            'message': 'Sync completed',
            'result': sync_result,
            'records': records
        }), 200
        
    except Exception as e:
        print(f'❌ データ同期エラー: {e}')
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

# ============================================================
# Flutter Web 静的ファイル配信
# ============================================================

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve_flutter(path):
    """Flutter Web静的ファイルを配信"""
    try:
        if path == '':
            # ルートパスの場合はindex.htmlを返す
            return send_from_directory(FLUTTER_WEB_DIR, 'index.html')
        
        # 指定されたファイルを返す
        file_path = os.path.join(FLUTTER_WEB_DIR, path)
        
        if os.path.exists(file_path) and os.path.isfile(file_path):
            return send_from_directory(FLUTTER_WEB_DIR, path)
        else:
            # ファイルが見つからない場合はindex.htmlを返す（SPAルーティング対応）
            return send_from_directory(FLUTTER_WEB_DIR, 'index.html')
    except Exception as e:
        print(f'❌ ファイル配信エラー: {e}')
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    print('🚀 Unified Server起動')
    print('   ポート: 5060')
    print('   機能:')
    print('     - Flutter Web配信')
    print('     - Excel API (/api/generate-excel)')
    print('     - データベースAPI (/api/records, /api/sync)')
    print('     - ヘルスチェック (/api/health)')
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    app.run(host='0.0.0.0', port=5060, debug=False, threaded=True)
