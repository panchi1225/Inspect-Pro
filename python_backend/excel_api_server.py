#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Excel API Server
FlutterアプリからExcel生成リクエストを受け付けるAPIサーバー
"""

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import json
import os
import tempfile
from datetime import datetime
from excel_generator_advanced import create_inspection_report

app = Flask(__name__)
CORS(app)  # CORS対応

@app.route('/api/generate-excel', methods=['POST'])
def generate_excel():
    """
    Excel生成API
    
    リクエストボディ:
    {
        "machine_type": "油圧ショベル（PC200）",
        "machine_model": "油圧ショベル（PC200）",
        "machine_unit": "1号機",
        "site_name": "工事名",
        "month": 6,
        "year": 2025,
        "records": [...],
        "items": [...]
    }
    
    レスポンス:
    - 成功: Excelファイル（application/vnd.openxmlformats-officedocument.spreadsheetml.sheet）
    - 失敗: JSONエラーメッセージ
    """
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
        machine_info = f"{data.get('machine_model', '重機')}_{data.get('machine_unit', '')}".replace('/', '_')
        download_filename = f"点検表_{machine_info}_{data.get('year')}年{data.get('month')}月.xlsx"
        
        # Excelファイルを返す
        return send_file(
            output_path,
            mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            as_attachment=True,
            download_name=download_filename
        )
        
    except Exception as e:
        print(f'❌ Excel生成APIエラー: {e}')
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    """ヘルスチェックエンドポイント"""
    return jsonify({'status': 'ok', 'message': 'Excel API Server is running'}), 200

if __name__ == '__main__':
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    print('🚀 Excel API Server起動')
    print('   ポート: 5001')
    print('   エンドポイント:')
    print('     - POST /api/generate-excel')
    print('     - GET  /api/health')
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    app.run(host='0.0.0.0', port=5001, debug=True)
