import firebase_admin
from firebase_admin import credentials
import requests
import json

print("=" * 60)
print("🔒 Firebaseセキュリティルールの自動設定")
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
      allow read: if true;           // 誰でも読み取り可能
      allow write: if true;          // 書き込み許可（管理者が使用）
      
      match /items/{itemId} {
        allow read: if true;         // 点検項目も読み取り可能
        allow write: if true;        // 書き込み許可
      }
    }
    
    // ============================================
    // 重機データ
    // ============================================
    match /machines/{machineId} {
      allow read: if true;           // 誰でも読み取り可能
      allow write: if true;          // 書き込み許可（追加・削除可能）
    }
    
    // ============================================
    // 現場名マスタ
    // ============================================
    match /sites/{siteId} {
      allow read: if true;           // 誰でも読み取り可能
      allow write: if true;          // 書き込み許可（追加・削除可能）
    }
    
    // ============================================
    // 点検者マスタ
    // ============================================
    match /inspectors/{inspectorId} {
      allow read: if true;           // 誰でも読み取り可能
      allow write: if true;          // 書き込み許可（追加・削除可能）
    }
    
    // ============================================
    // 会社名マスタ
    // ============================================
    match /companies/{companyId} {
      allow read: if true;           // 誰でも読み取り可能
      allow write: if true;          // 書き込み許可（追加・削除可能）
    }
    
    // ============================================
    // 点検記録
    // ============================================
    match /inspections/{inspectionId} {
      allow read: if true;           // 誰でも読み取り可能
      allow create: if true;         // 新規作成は許可
      allow update: if true;         // 更新も許可
      allow delete: if true;         // 削除も許可
    }
    
    // ============================================
    // その他のコレクション（デフォルト拒否）
    // ============================================
    match /{document=**} {
      allow read: if true;           // 読み取りは許可
      allow write: if false;         // その他の書き込みは禁止
    }
  }
}
"""

print("\n" + "=" * 60)
print("📋 設定するセキュリティルール")
print("=" * 60)
print(security_rules_source)

print("\n" + "=" * 60)
print("🚀 Firebase REST APIで設定を試行")
print("=" * 60)

try:
    # アクセストークンを取得
    access_token = cred.get_access_token().access_token
    print("✅ アクセストークン取得成功")
    
    # Firestore Rules APIのエンドポイント
    url = f"https://firebaserules.googleapis.com/v1/projects/{project_id}/rulesets"
    
    # ルールセットの作成
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
    
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    
    print("\n📤 ルールセットを作成中...")
    response = requests.post(url, headers=headers, json=ruleset_data)
    
    if response.status_code == 200:
        ruleset = response.json()
        ruleset_name = ruleset.get("name")
        print(f"✅ ルールセット作成成功: {ruleset_name}")
        
        # ルールセットをリリース
        release_url = f"https://firebaserules.googleapis.com/v1/projects/{project_id}/releases/cloud.firestore"
        release_data = {
            "name": f"projects/{project_id}/releases/cloud.firestore",
            "rulesetName": ruleset_name
        }
        
        print("\n📤 ルールセットを公開中...")
        release_response = requests.patch(release_url, headers=headers, json=release_data)
        
        if release_response.status_code == 200:
            print("✅ セキュリティルールの公開成功！")
            print("\n" + "=" * 60)
            print("🎉 セキュリティルール設定完了")
            print("=" * 60)
            print("\n✅ 設定内容:")
            print("  1. マスタデータの追加・更新・削除が可能")
            print("  2. 点検データの追加・更新・削除が可能")
            print("  3. すべてのデータの読み取りが可能")
            print("\n⚠️  注意: URLを知っている人は上記の操作が可能です")
            print("  社内利用（5人程度）であれば問題ありません")
        else:
            print(f"❌ ルールセット公開失敗: {release_response.status_code}")
            print(f"エラー内容: {release_response.text}")
            raise Exception("ルールセット公開に失敗しました")
    else:
        print(f"❌ ルールセット作成失敗: {response.status_code}")
        print(f"エラー内容: {response.text}")
        raise Exception("ルールセット作成に失敗しました")
        
except Exception as e:
    print(f"\n❌ 自動設定に失敗しました: {e}")
    print("\n" + "=" * 60)
    print("🔧 手動設定が必要です")
    print("=" * 60)
    print("\n📋 手動設定手順:")
    print(f"  1. Firebase Console を開く")
    print(f"     https://console.firebase.google.com/project/{project_id}/firestore/rules")
    print(f"\n  2. 上記のセキュリティルールをコピー")
    print(f"\n  3. Firestore Database → Rules タブを開く")
    print(f"\n  4. 既存のルールを削除")
    print(f"\n  5. 上記のルールを貼り付け")
    print(f"\n  6. 「公開」ボタンをクリック")

print("\n" + "=" * 60)
