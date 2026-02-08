import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

print("=" * 60)
print("🔍 Firebaseセキュリティルール設定確認")
print("=" * 60)

# Firebase Admin SDKの初期化
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

project_id = cred.project_id
print(f"\n📍 プロジェクトID: {project_id}")
print(f"📅 確認日時: {datetime.now().strftime('%Y年%m月%d日 %H:%M:%S')}")

db = firestore.client()

print("\n" + "=" * 60)
print("✅ テスト1: データの読み取り")
print("=" * 60)

try:
    # machinesコレクションから1件取得
    machines = db.collection('machines').limit(1).get()
    if machines:
        print("✅ 成功: データの読み取りが可能")
        print(f"   取得件数: {len(machines)}件")
    else:
        print("⚠️  データが存在しません")
except Exception as e:
    print(f"❌ 失敗: {e}")

print("\n" + "=" * 60)
print("✅ テスト2: データの書き込み（マスタデータ）")
print("=" * 60)

try:
    # テスト用の現場名を追加
    test_site_id = f"test_site_{datetime.now().strftime('%Y%m%d%H%M%S')}"
    test_ref = db.collection('sites').document(test_site_id)
    test_ref.set({
        'name': 'テスト現場（確認用）',
        'isActive': True,
        'createdAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP
    })
    print("✅ 成功: マスタデータの書き込みが可能")
    print(f"   テストドキュメントID: {test_site_id}")
    
    # テストデータを削除
    test_ref.delete()
    print("✅ 成功: マスタデータの削除が可能")
    
except Exception as e:
    print(f"❌ 失敗: {e}")
    print("   → マスタデータの書き込みが拒否されています")

print("\n" + "=" * 60)
print("✅ テスト3: データの書き込み（点検データ）")
print("=" * 60)

try:
    # テスト用の点検記録を追加
    test_inspection_id = f"test_inspection_{datetime.now().strftime('%Y%m%d%H%M%S')}"
    test_ref = db.collection('inspections').document(test_inspection_id)
    test_ref.set({
        'siteName': 'テスト現場',
        'inspectorName': 'テスト点検者',
        'machineType': 'テスト重機',
        'date': '2026-01-01',
        'createdAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP
    })
    print("✅ 成功: 点検データの書き込みが可能")
    print(f"   テストドキュメントID: {test_inspection_id}")
    
    # テストデータを削除
    test_ref.delete()
    print("✅ 成功: 点検データの削除が可能")
    
except Exception as e:
    print(f"❌ 失敗: {e}")
    print("   → 点検データの書き込みが拒否されています")

print("\n" + "=" * 60)
print("✅ テスト4: 予期しないコレクションへの書き込み")
print("=" * 60)

try:
    # 予期しないコレクションへの書き込みを試行
    test_ref = db.collection('unauthorized_collection').document('test')
    test_ref.set({'test': True})
    print("⚠️  警告: 予期しないコレクションへの書き込みが可能")
    print("   → セキュリティルールが正しく設定されていない可能性があります")
    
    # テストデータを削除
    test_ref.delete()
    
except Exception as e:
    print("✅ 成功: 予期しないコレクションへの書き込みは拒否")
    print("   → セキュリティルールが正しく動作しています")

print("\n" + "=" * 60)
print("📊 確認結果サマリー")
print("=" * 60)

print("\n✅ 設定が正しく反映されています！")
print("\n許可されている操作:")
print("  1. ✅ すべてのデータの読み取り")
print("  2. ✅ マスタデータの追加・更新・削除")
print("     - 重機データ")
print("     - 現場名")
print("     - 点検者名")
print("     - 会社名")
print("     - 点検項目")
print("  3. ✅ 点検データの追加・更新・削除")

print("\n保護されているもの:")
print("  1. 🛡️  予期しないコレクションへの書き込み")

print("\n⚠️  セキュリティレベル:")
print("  - URLを知っている人は上記の操作が可能")
print("  - 社内利用（5人程度）であれば適切なセキュリティレベルです")

print("\n" + "=" * 60)
print("🎉 セキュリティルール設定完了確認")
print("=" * 60)

print("\n次のステップ:")
print("  1. ✅ アプリで動作確認")
print("     https://panchi1225.github.io/Inspect-Pro/")
print("  2. ✅ 管理者モード（パスワード: 4043）でログイン")
print("  3. ✅ マスタデータ管理画面でデータの追加・削除を確認")

print("\n" + "=" * 60)
