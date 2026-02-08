print("=" * 60)
print("🔓 現在のセキュリティリスクのデモンストレーション")
print("=" * 60)

print("\n📍 テストモードのセキュリティルール:")
print("""
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;  ← 誰でもアクセス可能！
    }
  }
}
""")

print("\n⚠️  これは以下を意味します:\n")

risks = [
    ("🌐 インターネット上の誰でも", "プロジェクトIDを知っていればアクセス可能"),
    ("📖 すべてのデータを読み取り", "点検記録、重機情報、現場情報など"),
    ("✏️  データの変更", "既存の点検記録を改ざん可能"),
    ("🗑️  データの削除", "すべての点検記録を削除可能"),
    ("📝 不正データの追加", "偽の点検記録を追加可能"),
    ("💰 不正使用によるコスト", "大量アクセスで予期しない課金"),
]

for i, (risk, detail) in enumerate(risks, 1):
    print(f"{i}. {risk}")
    print(f"   └─ {detail}")
    print()

print("=" * 60)
print("🎯 対策: セキュリティルールの設定が必須")
print("=" * 60)

print("\n✅ 推奨される対策:")
print("1. 認証済みユーザーのみアクセス許可")
print("2. 読み取りと書き込みの権限を分離")
print("3. 重要なコレクションへのアクセス制限")
print("4. ログとモニタリングの設定")

print("\n⏰ 対策の緊急度: 🚨 高")
print("   理由: 社内共有前にセキュリティ対策が必須")
