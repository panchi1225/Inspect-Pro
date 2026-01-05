# 🔥 Firestore Security Rules 修正手順

## 🚨 現在の問題

マスタデータ管理画面でデータ追加時にエラーが発生する原因：
**Firestore Security Rulesがデフォルトでアクセスを拒否している**

## ✅ 解決方法（5分で完了）

### ステップ1: Firebase Consoleを開く

以下のURLを開いてください：
```
https://console.firebase.google.com/project/inspect-pro-22e0a/firestore/rules
```

または：
1. https://console.firebase.google.com/ を開く
2. プロジェクト「inspect-pro-22e0a」を選択
3. 左メニュー → **Firestore Database**
4. 上部タブ → **ルール（Rules）**

### ステップ2: 現在のルールを確認

現在のルールは以下のようになっている可能性があります：

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;  // ← すべて拒否！
    }
  }
}
```

### ステップ3: ルールを更新

**以下のルールに置き換えてください**（コピー＆ペースト）：

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 社内専用アプリケーション用（URLを知る人のみアクセス可能）
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

### ステップ4: 公開

1. 右上の **「公開」** ボタンをクリック
2. 確認ダイアログが出たら **「公開」** をクリック
3. 「ルールが正常に公開されました」のメッセージを確認

### ステップ5: 動作確認

1. 一時プレビューURLを開く：
   ```
   https://5060-iytxacjlxvuwcl3b2vw9x-cbeee0f9.sandbox.novita.ai
   ```

2. 管理者でログイン（パスワード: **4043**）

3. 「マスタデータ管理」ボタンをクリック

4. 以下のテストデータが表示されているはずです：
   - **現場名**: 本社工場、第二工場、営業所A
   - **点検者名**: 山田太郎、佐藤花子、鈴木一郎
   - **所有会社名**: ABC建設株式会社、XYZ運送株式会社、自社保有

5. 新しいデータを追加してみる（例: 現場名「テスト工場」）

6. エラーが出なければ成功！✅

## 🔒 セキュリティに関する注意事項

### 現在の設定（社内専用）
```javascript
allow read, write: if true;  // すべて許可
```

**適用ケース**:
- 社内専用アプリケーション
- URLを知る社内の人間のみがアクセス
- インターネット上に公開されていない

**メリット**:
- シンプルで管理しやすい
- 認証不要で使いやすい

**リスク**:
- URLを知れば誰でもアクセス可能
- データの改ざんリスクあり

### 将来的な改善案（必要に応じて）

もしセキュリティを強化したい場合は、以下の方法があります：

#### 方法1: IP制限（Firebase Hosting + Cloud Functions）
- 特定のIPアドレスからのみアクセス許可
- 社内ネットワークからのみアクセス可能

#### 方法2: Firebase Authentication
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // ログイン済みユーザーのみアクセス可能
      allow read, write: if request.auth != null;
    }
  }
}
```

## 📊 トラブルシューティング

### Q1: ルールを更新したが、まだエラーが出る

**解決策**:
1. ブラウザのキャッシュをクリア（Ctrl+Shift+Delete）
2. 数分待ってから再試行（ルール反映に時間がかかる場合がある）
3. F12キーで開発者ツールを開き、Consoleタブでエラー内容を確認

### Q2: 「公開」ボタンが見当たらない

**解決策**:
- 画面を下にスクロール
- 右上に「公開」ボタンがあるはず
- または、ルールエディタの下部に「公開」ボタンがある

### Q3: データが表示されない

**確認事項**:
1. Firestore Security Rulesが公開されているか確認
2. Firebase Consoleで直接データを確認：
   ```
   https://console.firebase.google.com/project/inspect-pro-22e0a/firestore/data
   ```
3. sitesコレクション、inspectorsコレクション、companiesコレクションが存在するか確認

### Q4: Admin SDKからは書き込めるが、Webアプリからは書き込めない

**原因**:
- Admin SDKはSecurity Rulesをバイパスする
- Webアプリ（クライアント側）はSecurity Rulesに従う

**解決策**:
- Security Rulesを`allow read, write: if true;`に設定

## 📞 サポート情報

Firebase Consoleのドキュメント:
- https://firebase.google.com/docs/firestore/security/get-started

Firestore Security Rulesガイド:
- https://firebase.google.com/docs/firestore/security/rules-structure

---

**最終更新**: 2026-01-05
**対象プロジェクト**: inspect-pro-22e0a
**アプリケーション**: Inspect Pro（社内専用）
