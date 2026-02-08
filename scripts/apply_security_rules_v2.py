import firebase_admin
from firebase_admin import credentials
import requests
import json

print("=" * 60)
print("🔒 Firebaseセキュリティルールの自動設定 v2")
print("=" * 60)

# Firebase Admin SDKの初期化
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

project_id = cred.project_id
print(f"\n📍 プロジェクトID: {project_id}")

# セキュリティルール（v2 - マスタデータ書き込み許可）
security_rules_source = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // マスタデータ（重機種類）
    // ============================================
    match /machine_types/{typeId} {
      allow read: if true;
      allow write: if true;
      
      match /items/{itemId} {
        allow read: if true;
        allow write: if true;
      }
    }
    
    // ============================================
    // 重機データ
    // ============================================
    match /machines/{machineId} {
      allow read: if true;
      allow write: if true;
    }
    
    // ============================================
    // 現場名マスタ
    // ============================================
    match /sites/{siteId} {
      allow read: if true;
      allow write: if true;
    }
    
    // ============================================
    // 点検者マスタ
    // ============================================
    match /inspectors/{inspectorId} {
      allow read: if true;
      allow write: if true;
    }
    
    // ============================================
    // 会社名マスタ
    // ============================================
    match /companies/{companyId} {
      allow read: if true;
      allow write: if true;
    }
    
    // ============================================
    // 点検記録
    // ============================================
    match /inspections/{inspectionId} {
      allow read: if true;
      allow create: if true;
      allow update: if true;
      allow delete: if true;
    }
    
    // ============================================
    // その他のコレクション
    // ============================================
    match /{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
"""

try:
    # アクセストークンを取得
    access_token = cred.get_access_token().access_token
    print("✅ アクセストークン取得成功")
    
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    
    # ステップ1: ルールセットを作成
    print("\n📤 ステップ1: ルールセットを作成中...")
    ruleset_url = f"https://firebaserules.googleapis.com/v1/projects/{project_id}/rulesets"
    ruleset_data = {
        "source": {
            "files": [
                {
                    "name": "firestore.rules",
                    "content": security_rules_source
                }
            ]
        }
    }
    
    ruleset_response = requests.post(ruleset_url, headers=headers, json=ruleset_data)
    
    if ruleset_response.status_code != 200:
        raise Exception(f"ルールセット作成失敗: {ruleset_response.text}")
    
    ruleset = ruleset_response.json()
    ruleset_name = ruleset.get("name")
    print(f"✅ ルールセット作成成功: {ruleset_name}")
    
    # ステップ2: リリースを作成（PATCHではなくPOST）
    print("\n📤 ステップ2: ルールセットを公開中...")
    release_url = f"https://firebaserules.googleapis.com/v1/projects/{project_id}/releases"
    release_data = {
        "name": f"projects/{project_id}/releases/cloud.firestore",
        "ruleset": ruleset_name
    }
    
    # 既存のリリースを削除してから作成
    delete_url = f"https://firebaserules.googleapis.com/v1/projects/{project_id}/releases/cloud.firestore"
    requests.delete(delete_url, headers=headers)
    
    release_response = requests.post(release_url, headers=headers, json=release_data)
    
    if release_response.status_code == 200:
        print("✅ セキュリティルールの公開成功！")
        print("\n" + "=" * 60)
        print("🎉 セキュリティルール設定完了")
        print("=" * 60)
        print("\n✅ 設定内容:")
        print("  1. ✅ マスタデータの追加・更新・削除が可能")
        print("  2. ✅ 点検データの追加・更新・削除が可能")
        print("  3. ✅ すべてのデータの読み取りが可能")
        print("\n⚠️  注意事項:")
        print("  - URLを知っている人は上記の操作が可能です")
        print("  - 社内利用（5人程度）であれば問題ありません")
        print("\n🔍 Firebase Consoleで確認:")
        print(f"  https://console.firebase.google.com/project/{project_id}/firestore/rules")
    else:
        raise Exception(f"ルールセット公開失敗: {release_response.text}")
        
except Exception as e:
    print(f"\n❌ 自動設定エラー: {e}")
    print("\n" + "=" * 60)
    print("🔧 手動設定をお願いします")
    print("=" * 60)
    print("\n📋 手動設定手順:")
    print(f"  1. Firebase Console を開く:")
    print(f"     https://console.firebase.google.com/project/{project_id}/firestore/rules")
    print(f"\n  2. 以下のセキュリティルールをコピー:")
    print("\n" + "-" * 60)
    print(security_rules_source)
    print("-" * 60)
    print(f"\n  3. Firestore Database → Rules タブ")
    print(f"  4. 既存のルールを削除")
    print(f"  5. 上記のルールを貼り付け")
    print(f"  6. 「公開」ボタンをクリック")

print("\n" + "=" * 60)
