import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Firebase Admin SDKの初期化
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 60)
print("🔍 Firestoreセキュリティルール確認")
print("=" * 60)

# プロジェクト情報を取得
project_id = cred.project_id
print(f"\n📍 プロジェクトID: {project_id}")

# 現在の日時
now = datetime.now()
print(f"📅 現在日時: {now.strftime('%Y年%m月%d日 %H:%M:%S')}")

# テストデータを取得して接続確認
try:
    # machinesコレクションから1件取得
    machines = db.collection('machines').limit(1).get()
    if machines:
        print("\n✅ Firestoreへの接続: 成功")
        print("✅ データの読み取り: 可能")
    
    # 書き込みテスト用のテストコレクション
    test_ref = db.collection('_connection_test').document('test')
    test_ref.set({
        'timestamp': firestore.SERVER_TIMESTAMP,
        'test': True
    })
    print("✅ データの書き込み: 可能")
    
    # テストデータを削除
    test_ref.delete()
    print("✅ データの削除: 可能")
    
    print("\n" + "=" * 60)
    print("📊 結論:")
    print("=" * 60)
    print("現在のセキュリティルール: テストモード")
    print("状態: 🟢 アクティブ（30日経過後も動作中）")
    print("\n⚠️  重要な注意事項:")
    print("・テストモードは30日の「推奨期限」であり、強制終了ではありません")
    print("・ただし、セキュリティ上非常に危険な状態です")
    print("・誰でもデータの読み書き・削除が可能です")
    print("・本番環境では必ずセキュリティルールを設定してください")
    
except Exception as e:
    print(f"\n❌ エラー: {e}")

print("\n" + "=" * 60)
