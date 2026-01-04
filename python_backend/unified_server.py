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
        
        # マスタデータテーブル（現場名、点検者名、所有会社名）
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS master_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                data_type TEXT NOT NULL,
                name TEXT NOT NULL,
                created_at TEXT NOT NULL,
                UNIQUE(data_type, name)
            )
        ''')
        
        # 初期マスタデータの投入をスキップ（ユーザーがCSVで管理）
        print('✅ Master data initialization skipped (user manages via CSV)')
        
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

# エイリアス（マスタデータAPI用）
get_db_connection = get_db

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
# マスタデータ管理API
# ============================================================

# 現場名管理
@app.route('/api/master/sites', methods=['GET', 'POST', 'DELETE'])
def manage_sites():
    """現場名のCRUD操作"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        if request.method == 'GET':
            # 現場名一覧取得（master_dataからのみ取得、sort_order順）
            # inspection_recordsからは取得しない（削除したマスタが復活するのを防ぐため）
            cursor.execute('SELECT name FROM master_data WHERE data_type = "site" ORDER BY sort_order, name')
            sites = [row['name'] for row in cursor.fetchall()]
            
            conn.close()
            return jsonify({'sites': sites}), 200
        
        elif request.method == 'POST':
            # 現場名追加（master_dataテーブルに保存、sort_orderは最大値+1）
            data = request.get_json()
            site_name = data.get('siteName', '').strip()
            if not site_name:
                return jsonify({'error': 'Site name is required'}), 400
            
            # 最大のsort_orderを取得
            cursor.execute('SELECT MAX(sort_order) FROM master_data WHERE data_type = "site"')
            max_order = cursor.fetchone()[0]
            new_order = (max_order + 1) if max_order else 1
            
            now = datetime.now().isoformat()
            cursor.execute(
                'INSERT OR IGNORE INTO master_data (data_type, name, created_at, sort_order) VALUES (?, ?, ?, ?)',
                ('site', site_name, now, new_order)
            )
            conn.commit()
            conn.close()
            
            print(f'✅ 現場追加: {site_name} (sort_order: {new_order})')
            return jsonify({'message': 'Site added', 'siteName': site_name}), 201
        
        elif request.method == 'DELETE':
            # 現場名削除（master_dataと関連レコードを削除）
            data = request.get_json()
            site_name = data.get('siteName', '').strip()
            if not site_name:
                return jsonify({'error': 'Site name is required'}), 400
            
            print(f'🔍 現場削除開始: {site_name}', flush=True)
            
            # 削除前の点検記録数を確認
            cursor.execute('SELECT COUNT(*) FROM inspection_records WHERE site_name = ?', (site_name,))
            before_count = cursor.fetchone()[0]
            print(f'   削除対象の点検記録数: {before_count}件', flush=True)
            
            # master_dataから削除
            cursor.execute('DELETE FROM master_data WHERE data_type = "site" AND name = ?', (site_name,))
            master_deleted = cursor.rowcount
            print(f'   master_data削除: {master_deleted}件', flush=True)
            
            # 関連する点検記録も削除（完全一致のみ）
            cursor.execute('DELETE FROM inspection_records WHERE site_name = ?', (site_name,))
            records_deleted = cursor.rowcount
            print(f'   inspection_records削除: {records_deleted}件', flush=True)
            
            conn.commit()
            
            # 削除後の確認
            cursor.execute('SELECT COUNT(*) FROM inspection_records WHERE site_name = ?', (site_name,))
            after_count = cursor.fetchone()[0]
            print(f'   削除後の残存レコード数: {after_count}件', flush=True)
            
            conn.close()
            
            print(f'✅ 現場削除完了: {site_name} (マスタ: {master_deleted}件, 点検記録: {records_deleted}件)', flush=True)
            return jsonify({
                'message': 'Site deleted', 
                'deletedMaster': master_deleted,
                'deletedRecords': records_deleted,
                'siteName': site_name
            }), 200
    
    except Exception as e:
        print(f'❌ 現場名管理エラー: {e}')
        return jsonify({'error': str(e)}), 500

# 点検者名管理
@app.route('/api/master/inspectors', methods=['GET', 'POST', 'DELETE'])
def manage_inspectors():
    """点検者名のCRUD操作"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        if request.method == 'GET':
            # 点検者名一覧取得（master_dataからのみ取得、inspection_recordsは参照しない）
            cursor.execute('SELECT name FROM master_data WHERE data_type = "inspector" ORDER BY sort_order, name')
            inspectors = [row['name'] for row in cursor.fetchall()]
            
            conn.close()
            return jsonify({'inspectors': inspectors}), 200
        
        elif request.method == 'POST':
            # 点検者名追加（master_dataテーブルに保存、sort_orderは最大値+1）
            data = request.get_json()
            inspector_name = data.get('inspectorName', '').strip()
            if not inspector_name:
                return jsonify({'error': 'Inspector name is required'}), 400
            
            # 最大のsort_orderを取得
            cursor.execute('SELECT MAX(sort_order) FROM master_data WHERE data_type = "inspector"')
            max_order = cursor.fetchone()[0]
            new_order = (max_order + 1) if max_order else 1
            
            now = datetime.now().isoformat()
            cursor.execute(
                'INSERT OR IGNORE INTO master_data (data_type, name, created_at, sort_order) VALUES (?, ?, ?, ?)',
                ('inspector', inspector_name, now, new_order)
            )
            conn.commit()
            conn.close()
            
            print(f'✅ 点検者追加: {inspector_name} (sort_order: {new_order})')
            return jsonify({'message': 'Inspector added', 'inspectorName': inspector_name}), 201
        
        elif request.method == 'DELETE':
            # 点検者名削除（master_dataからのみ削除、inspection_recordsは保持）
            data = request.get_json()
            inspector_name = data.get('inspectorName', '').strip()
            if not inspector_name:
                return jsonify({'error': 'Inspector name is required'}), 400
            
            # master_dataから削除（点検記録は削除しない）
            cursor.execute('DELETE FROM master_data WHERE data_type = "inspector" AND name = ?', (inspector_name,))
            
            conn.commit()
            conn.close()
            
            print(f'✅ 点検者削除: {inspector_name}')
            return jsonify({'message': 'Inspector deleted'}), 200
    
    except Exception as e:
        print(f'❌ 点検者名管理エラー: {e}')
        return jsonify({'error': str(e)}), 500

# 所有会社名管理（master_dataテーブルを使用し、sort_orderで順序管理）
@app.route('/api/master/companies', methods=['GET', 'POST', 'DELETE'])
def manage_companies():
    """所有会社名のCRUD操作"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        if request.method == 'GET':
            # 所有会社名一覧取得（master_dataからsort_order順）
            cursor.execute('SELECT name FROM master_data WHERE data_type = "company" ORDER BY sort_order, name')
            companies = [row['name'] for row in cursor.fetchall()]
            conn.close()
            return jsonify({'companies': companies}), 200
        
        elif request.method == 'POST':
            # 所有会社名追加（master_dataテーブルに保存、sort_orderは最大値+1）
            data = request.get_json()
            company_name = data.get('companyName', '').strip()
            if not company_name:
                return jsonify({'error': 'Company name is required'}), 400
            
            # 最大のsort_orderを取得
            cursor.execute('SELECT MAX(sort_order) FROM master_data WHERE data_type = "company"')
            max_order = cursor.fetchone()[0]
            new_order = (max_order + 1) if max_order else 1
            
            now = datetime.now().isoformat()
            cursor.execute(
                'INSERT OR IGNORE INTO master_data (data_type, name, created_at, sort_order) VALUES (?, ?, ?, ?)',
                ('company', company_name, now, new_order)
            )
            conn.commit()
            conn.close()
            
            print(f'✅ 会社追加: {company_name} (sort_order: {new_order})')
            return jsonify({'message': 'Company added', 'companyName': company_name}), 201
        
        elif request.method == 'DELETE':
            # 所有会社名削除（master_dataから削除）
            data = request.get_json()
            company_name = data.get('companyName', '').strip()
            if not company_name:
                return jsonify({'error': 'Company name is required'}), 400
            
            cursor.execute('DELETE FROM master_data WHERE data_type = "company" AND name = ?', (company_name,))
            deleted_count = cursor.rowcount
            conn.commit()
            conn.close()
            
            print(f'✅ 会社削除: {company_name}')
            return jsonify({'message': 'Company deleted'}), 200
    
    except Exception as e:
        print(f'❌ 所有会社名管理エラー: {e}')
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
