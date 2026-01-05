# 🚨 緊急対応事項（マスタデータ管理エラー）

## 📋 現在の状況

### ✅ 正常に動作しているもの
- 一時プレビューURL: https://5060-iytxacjlxvuwcl3b2vw9x-cbeee0f9.sandbox.novita.ai
- ローカルビルド・サーバー起動
- 画面表示・ログイン機能

### ❌ エラーが発生しているもの
- GitHub Pages: https://panchi1225.github.io/Inspect-Pro/
- マスタデータ管理画面でのデータ追加時にエラー

---

## 🔍 根本原因の分析

### 原因1: Web版Firebase設定の不完全性

**問題箇所**: `lib/firebase_options.dart` 54行目
```dart
appId: '1:706421185862:web:PLACEHOLDER',  // ← これが問題！
```

**影響**:
- Firebase Web SDKが正しく初期化されない
- Firestoreへの接続が失敗する
- マスタデータの追加・削除ができない

**解決方法**:
1. Firebase Console: https://console.firebase.google.com/project/inspect-pro-22e0a/settings/general
2. 「アプリ」セクションを確認
3. Webアプリが未登録の場合:
   - 「アプリを追加」→「ウェブ」
   - アプリ名: `Inspect Pro Web`
   - 「アプリを登録」をクリック
4. 設定画面で`App ID`をコピー（例: `1:706421185862:web:abc123def456`）
5. `lib/firebase_options.dart`の54行目を実際のApp IDに置き換え
6. 再ビルド:
   ```bash
   cd /home/user/flutter_app
   flutter build web --release --base-href="/Inspect-Pro/"
   ./deploy_to_github_pages.sh
   ```

### 原因2: Firestore Security Rulesが制限的

**問題**:
デフォルトのセキュリティルールが`allow read, write: if false;`になっている可能性

**解決方法**:
1. Firebase Console: https://console.firebase.google.com/project/inspect-pro-22e0a/firestore/rules
2. 現在のルールを以下に置き換え（社内専用アプリのため）:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 社内専用アプリケーション用ルール（認証なし）
    // すべてのコレクションへの読み書きを許可
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

3. 「公開」ボタンをクリック
4. 警告が出ても「公開」を確認（社内専用のため問題なし）

**⚠️ 注意**: 
- このルールは社内専用アプリケーション用です
- URLを知る社内の人間のみがアクセスすることを前提としています
- 外部公開する場合は、Firebase Authenticationと組み合わせてください

---

## 🔧 すぐに実施すべき手順（優先順位順）

### 1️⃣ 【最優先】Web版Firebase App IDの修正

```bash
# 1. Firebase Consoleで実際のApp IDを取得
# https://console.firebase.google.com/project/inspect-pro-22e0a/settings/general

# 2. lib/firebase_options.dartを編集
# 54行目のPLACEHOLDERを実際のApp IDに置き換え

# 3. 再ビルド（GitHub Pages用）
cd /home/user/flutter_app
flutter build web --release --base-href="/Inspect-Pro/"

# 4. デプロイ
./deploy_to_github_pages.sh
```

### 2️⃣ Firestore Security Rulesの更新

```bash
# Firebase Console経由で手動更新（上記のルールをコピペ）
# https://console.firebase.google.com/project/inspect-pro-22e0a/firestore/rules
```

### 3️⃣ 動作確認

1. **一時プレビュー** (App ID修正不要):
   - https://5060-iytxacjlxvuwcl3b2vw9x-cbeee0f9.sandbox.novita.ai
   - こちらは現在正常動作中

2. **GitHub Pages** (App ID修正後):
   - https://panchi1225.github.io/Inspect-Pro/
   - App ID修正とデプロイ後にテスト

3. **テスト項目**:
   - [ ] ログイン画面の表示
   - [ ] 管理者ログイン（パスワード: 4043）
   - [ ] ホーム画面のボタン表示
   - [ ] マスタデータ管理画面を開く
   - [ ] 現場名を追加（例: テスト現場）
   - [ ] 点検者名を追加（例: テスト太郎）
   - [ ] 所有会社名を追加（例: テスト株式会社）
   - [ ] 追加したデータが画面に表示されるか確認
   - [ ] データを削除して、削除されるか確認

---

## 📊 技術詳細（参考情報）

### Firebase Web App IDの確認方法

Firebase ConsoleでWebアプリを登録すると、以下のような設定が生成されます：

```javascript
const firebaseConfig = {
  apiKey: "AIzaSyBE5E6wBmViEU-2wdppL65uU21iLLKPWZk",
  authDomain: "inspect-pro-22e0a.firebaseapp.com",
  projectId: "inspect-pro-22e0a",
  storageBucket: "inspect-pro-22e0a.firebasestorage.app",
  messagingSenderId: "706421185862",
  appId: "1:706421185862:web:abc123def456"  // ← この値が必要
};
```

### ブラウザ開発者ツールでのエラー確認方法

1. GitHub Pagesを開く
2. F12キーを押して開発者ツールを開く
3. **Console**タブを確認
4. エラーメッセージを確認（例）:
   ```
   [ERROR] Firebase: Error (auth/invalid-api-key)
   [ERROR] Firestore: PERMISSION_DENIED
   ```

---

## 📞 サポート情報

### トラブルシューティング

**Q: App IDを修正したが、まだエラーが出る**
A: 以下を確認してください:
1. ブラウザのキャッシュをクリア（Ctrl+Shift+Delete）
2. Firestore Security Rulesが正しく公開されているか確認
3. Firebase Consoleでプロジェクトが有効化されているか確認

**Q: 一時プレビューURLは動くが、GitHub Pagesが動かない**
A: base-hrefの違いが原因です:
- 一時プレビュー: `--base-href="/"`
- GitHub Pages: `--base-href="/Inspect-Pro/"`

**Q: Security Rulesを更新したが反映されない**
A: 
1. Firestore Consoleで「公開」ボタンを確実にクリックしたか確認
2. 数分待ってから再試行
3. ブラウザのキャッシュをクリア

---

## 📅 最終更新

- 作成日: 2026-01-05
- 最終更新: 2026-01-05
- 対応状況: App ID修正待ち、Security Rules更新待ち
