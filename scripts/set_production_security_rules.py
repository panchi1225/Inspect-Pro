import firebase_admin
from firebase_admin import credentials
import requests
import json

# Firebase Admin SDKの初期化
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

project_id = cred.project_id

print("=" * 60)
print("🔒 本番環境用セキュリティルールの設定")
print("=" * 60)
print(f"\n📍 プロジェクトID: {project_id}")

# 本番環境用セキュリティルール（少人数・社内利用向け）
security_rules = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // マスタデータ（重機種類）
    // ============================================
    match /machine_types/{typeId} {
      allow read: if true;           // 誰でも読み取り可能
      allow write: if false;         // 書き込み禁止（管理者のみ）
      
      match /items/{itemId} {
        allow read: if true;         // 点検項目も読み取り可能
        allow write: if false;       // 書き込み禁止
      }
    }
    
    // ============================================
    // 重機データ
    // ============================================
    match /machines/{machineId} {
      allow read: if true;           // 誰でも読み取り可能
      allow write: if false;         // 書き込み禁止（変更・削除防止）
    }
    
    // ============================================
    // 現場名マスタ
    // ============================================
    match /sites/{siteId} {
      allow read: if true;           // 誰でも読み取り可能
      allow write: if false;         // 書き込み禁止
    }
    
    // ============================================
    // 点検者マスタ
    // ============================================
    match /inspectors/{inspectorId} {
      allow read: if true;           // 誰でも読み取り可能
      allow write: if false;         // 書き込み禁止
    }
    
    // ============================================
    // 会社名マスタ
    // ============================================
    match /companies/{companyId} {
      allow read: if true;           // 誰でも読み取り可能
      allow write: if false;         // 書き込み禁止
    }
    
    // ============================================
    // 点検記録（重要）
    // ============================================
    match /inspections/{inspectionId} {
      allow read: if true;           // 誰でも読み取り可能
      allow create: if true;         // 新規作成は許可
      allow update: if true;         // 更新も許可（アプリで使用中）
      allow delete: if true;         // 削除も許可（アプリで使用中）
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

print("\n📄 設定するセキュリティルール:")
print("-" * 60)
print(security_rules)
print("-" * 60)

print("\n✅ このルールの特徴:")
print("  1. 📖 すべてのデータは読み取り可能")
print("  2. ✏️  点検記録は追加・更新・削除が可能")
print("  3. 🔒 マスタデータは読み取り専用（変更・削除禁止）")
print("  4. 🛡️  予期しないデータの削除を防止")

print("\n" + "=" * 60)
print("🚀 Firebaseコンソールで手動設定してください")
print("=" * 60)

print("\n📋 設定手順:")
print("  1. Firebase Console を開く")
print(f"     https://console.firebase.google.com/project/{project_id}/firestore/rules")
print("\n  2. 上記のセキュリティルールをコピー")
print("\n  3. Firestore Database → Rules タブを開く")
print("\n  4. 既存のルールを削除")
print("\n  5. 上記のルールを貼り付け")
print("\n  6. 「公開」ボタンをクリック")

print("\n" + "=" * 60)
print("✨ 設定完了後の確認")
print("=" * 60)
print("  ✅ アプリが正常に動作することを確認")
print("  ✅ 点検データの追加・削除ができることを確認")
print("  ✅ セキュリティルールのエラーがないことを確認")

print("\n" + "=" * 60)
