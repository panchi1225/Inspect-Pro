# 📘 GitHub Pages セットアップ手順

## ✅ デプロイ完了済み

既に `gh-pages` ブランチにデプロイ済みです。  
以下の手順でGitHub Pages設定を行ってください（初回のみ）。

---

## 🔧 GitHub Pages 有効化手順

### 1. GitHubリポジトリの設定ページにアクセス

```
https://github.com/panchi1225/Inspect-Pro/settings/pages
```

### 2. Source（ソース）設定

画面中央の **"Build and deployment"** セクションで：

1. **Source** ドロップダウンをクリック
2. **"Deploy from a branch"** を選択

### 3. Branch（ブランチ）設定

1. **Branch** ドロップダウンをクリック
2. **"gh-pages"** を選択
3. フォルダは **"/ (root)"** のまま
4. **"Save"** ボタンをクリック

### 4. デプロイ完了を待つ

- 保存後、自動的にデプロイが開始されます
- 画面上部に緑色のバーが表示され、デプロイ状況が確認できます
- 通常1-2分で完了します

### 5. アクセス確認

デプロイ完了後、以下のURLにアクセスできます：

```
https://panchi1225.github.io/Inspect-Pro/
```

---

## 🔄 今後の更新方法

### 自動更新（推奨）

コードを更新してGitHubにプッシュ後、以下のコマンドを実行：

```bash
./deploy_to_github_pages.sh
```

このスクリプトが自動的に：
1. Flutter Webビルド
2. gh-pagesブランチへのデプロイ

を実行します。数分後にWebサイトが更新されます。

### 手動更新

```bash
# 1. Webビルド
flutter build web --release --base-href "/Inspect-Pro/"

# 2. gh-pagesブランチにデプロイ
cd build/web
git init
git add -A
git commit -m "Update $(date '+%Y-%m-%d')"
git branch -M gh-pages
git remote add origin https://github.com/panchi1225/Inspect-Pro.git
git push -f origin gh-pages
cd ../..
```

---

## ❓ トラブルシューティング

### 問題: 404 Not Found

**原因:** GitHub Pagesが有効化されていない

**解決策:**
1. 上記の「GitHub Pages 有効化手順」を実行
2. 1-2分待ってから再度アクセス

### 問題: 古いバージョンが表示される

**原因:** ブラウザキャッシュ

**解決策:**
- スーパーリロード: `Ctrl + Shift + R` (Windows/Linux)
- スーパーリロード: `Cmd + Shift + R` (Mac)

### 問題: ビルドエラー

**原因:** Flutterの依存関係

**解決策:**
```bash
flutter clean
flutter pub get
flutter build web --release --base-href "/Inspect-Pro/"
```

---

## 📊 デプロイ状況の確認

GitHubリポジトリの **"Actions"** タブで、デプロイ状況を確認できます：

```
https://github.com/panchi1225/Inspect-Pro/deployments
```

---

## 📝 補足情報

### カスタムドメイン（オプション）

独自ドメインを使用する場合：

1. `web/CNAME` ファイルにドメイン名を記載
2. DNSレコードを設定
   - `CNAME` レコード: `panchi1225.github.io` を指定

### HTTPS

GitHub Pagesは自動的にHTTPSを有効化します。  
設定 → Pages → "Enforce HTTPS" にチェックを入れてください。

---

**最終更新**: 2025年1月4日  
**バージョン**: 1.0.0
