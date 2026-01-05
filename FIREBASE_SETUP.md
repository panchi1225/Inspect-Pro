# 🔥 Firebase セットアップ手順（マスターデータ管理エラー対応）

## ❌ 発生しているエラー

GitHub Pagesのマスターデータ管理画面でデータ追加時にエラーが発生する。

**原因:** Firestore Security Rulesが制限的な設定になっている

---

## ✅ 解決方法：Firestore Security Rulesの更新

### ステップ1: Firebase Consoleにアクセス

```
https://console.firebase.google.com/project/inspect-pro-22e0a/firestore/rules
```

または：

1. https://console.firebase.google.com/ にアクセス
2. プロジェクト「inspect-pro-22e0a」を選択
3. 左メニュー → **Firestore Database**
4. 上部タブ → **ルール（Rules）**

### ステップ2: 現在のルールを確認

現在のルールが以下のようになっている可能性があります：

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;  // すべて拒否
    }
  }
}
```

### ステップ3: ルールを更新

以下のルールに**完全に置き換え**してください：

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 社内専用アプリケーションのため、全アクセスを許可
    // 注意: 本番環境では認証を追加することを推奨
    
    match /{document=**} {
      allow read: if true;   // すべて読み取り可能
      allow write: if true;  // すべて書き込み可能
    }
  }
}
```

### ステップ4: 公開

1. 右上の **「公開（Publish）」** ボタンをクリック
2. 確認ダイアログで **「公開」** をクリック

### ステップ5: 動作確認

1. GitHub Pagesのアプリにアクセス
   ```
   https://panchi1225.github.io/Inspect-Pro/
   ```

2. 管理者でログイン（パスワード: 4043）

3. **マスタデータ管理**をクリック

4. 現場名を追加してみる
   - 「現場名を追加」ボタンをクリック
   - 例: "テスト現場A"
   - 保存

5. エラーが出ずに追加されることを確認 ✅

---

## 🔒 セキュリティについて

### 現在の設定（社内専用）

- **アクセス制限**: なし（URLを知る人全員）
- **認証**: アプリ内簡易認証のみ
- **適用範囲**: 社内専用アプリケーション

### 将来の強化案（オプション）

より厳格なセキュリティが必要な場合：

**1. Firebase Authenticationの追加**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**2. IPアドレス制限**
- Firebase Hostingのリダイレクト機能を使用
- Cloud Functionsでカスタム認証

**3. ロールベースアクセス制御**
```
match /sites/{siteId} {
  allow read: if true;
  allow write: if request.auth.token.admin == true;
}
```

---

## 🆘 トラブルシューティング

### 問題1: ルール更新後もエラーが出る

**解決策:**
1. ブラウザキャッシュをクリア（Ctrl+Shift+R）
2. 1-2分待ってから再度アクセス
3. ブラウザのコンソール（F12）でエラーメッセージを確認

### 問題2: 「permission-denied」エラー

**原因:** ルールが正しく公開されていない

**解決策:**
1. Firebase Consoleでルールを再度確認
2. 「公開」ボタンを再度クリック
3. 数分待ってから再試行

### 問題3: 「Missing or insufficient permissions」

**原因:** 古いルールがキャッシュされている

**解決策:**
```bash
# ブラウザの開発者ツール（F12）→ Consoleで実行
localStorage.clear();
sessionStorage.clear();
location.reload();
```

---

## 📊 現在のFirebase使用状況

### 無料枠の制限

- **読み取り**: 1日 50,000件
- **書き込み**: 1日 20,000件
- **ストレージ**: 1GB
- **ネットワーク**: 月10GB

### 推定使用量（社内10名想定）

- **1日の読み取り**: 約500件（余裕あり）
- **1日の書き込み**: 約50件（余裕あり）
- **ストレージ**: 約10MB（十分）

→ **無料枠で十分運用可能** ✅

---

## 📝 参考リンク

- **Firebase Console**: https://console.firebase.google.com/
- **Firestore Security Rules**: https://firebase.google.com/docs/firestore/security/get-started
- **プロジェクトURL**: https://console.firebase.google.com/project/inspect-pro-22e0a

---

**最終更新**: 2025年1月4日  
**対応者**: 開発チーム
