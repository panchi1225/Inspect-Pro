#!/usr/bin/env python3
import subprocess
import json
import os

print("=" * 60)
print("🔒 Firebaseセキュリティルール自動設定 (gcloud CLI)")
print("=" * 60)

# プロジェクトID
project_id = "inspect-pro-22e0a"
print(f"\n📍 プロジェクトID: {project_id}")

# セキュリティルールファイルを作成
security_rules = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // マスタデータ（重機種類）
    match /machine_types/{typeId} {
      allow read: if true;
      allow write: if true;
      
      match /items/{itemId} {
        allow read: if true;
        allow write: if true;
      }
    }
    
    // 重機データ
    match /machines/{machineId} {
      allow read: if true;
      allow write: if true;
    }
    
    // 現場名マスタ
    match /sites/{siteId} {
      allow read: if true;
      allow write: if true;
    }
    
    // 点検者マスタ
    match /inspectors/{inspectorId} {
      allow read: if true;
      allow write: if true;
    }
    
    // 会社名マスタ
    match /companies/{companyId} {
      allow read: if true;
      allow write: if true;
    }
    
    // 点検記録
    match /inspections/{inspectionId} {
      allow read: if true;
      allow create: if true;
      allow update: if true;
      allow delete: if true;
    }
    
    // その他のコレクション
    match /{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
"""

# ルールファイルを保存
rules_file = "/tmp/firestore.rules"
with open(rules_file, "w") as f:
    f.write(security_rules)

print("\n✅ セキュリティルールファイルを作成しました")
print(f"   ファイル: {rules_file}")

print("\n" + "=" * 60)
print("📋 設定するセキュリティルール")
print("=" * 60)
print(security_rules)

print("\n" + "=" * 60)
print("🚀 Firebase CLIで設定を試行")
print("=" * 60)

try:
    # Firebase CLIがインストールされているか確認
    result = subprocess.run(
        ["which", "firebase"],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        raise Exception("Firebase CLIがインストールされていません")
    
    print("✅ Firebase CLI検出")
    
    # Firebase CLIでデプロイ
    print("\n📤 セキュリティルールをデプロイ中...")
    
    # firebase.jsonを作成
    firebase_json = {
        "firestore": {
            "rules": "firestore.rules"
        }
    }
    
    with open("/tmp/firebase.json", "w") as f:
        json.dump(firebase_json, f)
    
    # ルールをデプロイ
    deploy_result = subprocess.run(
        [
            "firebase", "deploy",
            "--only", "firestore:rules",
            "--project", project_id,
            "--token", os.environ.get("FIREBASE_TOKEN", "")
        ],
        cwd="/tmp",
        capture_output=True,
        text=True
    )
    
    if deploy_result.returncode == 0:
        print("✅ セキュリティルールのデプロイ成功！")
        print("\n" + "=" * 60)
        print("🎉 セキュリティルール設定完了")
        print("=" * 60)
        print("\n✅ 設定内容:")
        print("  1. ✅ マスタデータの追加・更新・削除が可能")
        print("  2. ✅ 点検データの追加・更新・削除が可能")
        print("  3. ✅ すべてのデータの読み取りが可能")
    else:
        raise Exception(f"デプロイ失敗: {deploy_result.stderr}")
        
except Exception as e:
    print(f"\n❌ Firebase CLIでの設定に失敗: {e}")
    print("\n" + "=" * 60)
    print("🔧 Firestoreに直接書き込みを試行")
    print("=" * 60)
    
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
        from google.cloud import firestore_admin_v1
        
        # Firebase Admin初期化
        cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        
        print("\n✅ Firebase Admin SDK初期化成功")
        print("\n⚠️  直接的なルール設定はサポートされていません")
        print("    手動設定をお願いします")
        
    except Exception as e2:
        print(f"\n❌ Firebase Admin SDKでも失敗: {e2}")
    
    print("\n" + "=" * 60)
    print("🔧 手動設定が必要です")
    print("=" * 60)
    print("\n📋 手動設定手順:")
    print(f"  1. Firebase Console を開く:")
    print(f"     https://console.firebase.google.com/project/{project_id}/firestore/rules")
    print(f"\n  2. 上記のセキュリティルールをコピー")
    print(f"\n  3. Firestore Database → Rules タブ")
    print(f"  4. 既存のルールを削除")
    print(f"  5. 上記のルールを貼り付け")
    print(f"  6. 「公開」ボタンをクリック")

print("\n" + "=" * 60)
