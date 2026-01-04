import sys
sys.path.insert(0, '.')
from unified_server import *

if __name__ == '__main__':
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🚀 Unified Server起動 (ポート8080)")
    print("   ポート: 8080")
    print("   機能:")
    print("     - Flutter Web配信")
    print("     - Excel API (/api/generate-excel)")
    print("     - データベースAPI (/api/records, /api/sync)")
    print("     - ヘルスチェック (/api/health)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    app.run(host='0.0.0.0', port=8080, debug=False)
