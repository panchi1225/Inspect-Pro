#!/bin/bash

# Inspect Pro GitHub Pagesデプロイスクリプト
# 使い方: ./deploy_to_github_pages.sh

set -e

echo "🚀 Inspect Pro GitHub Pagesデプロイを開始します..."
echo ""

# 1. ビルド
echo "📦 Flutter Webビルド中..."
flutter clean
flutter pub get
flutter build web --release --base-href "/Inspect-Pro/"

# 2. gh-pagesブランチにデプロイ
echo ""
echo "🌐 gh-pagesブランチにデプロイ中..."

cd build/web

# Gitリポジトリを初期化
git init
git config user.name "Deploy Bot"
git config user.email "deploy@inspect-pro.local"

# すべてのファイルをコミット
git add -A
git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')"

# gh-pagesブランチにforce push
git branch -M gh-pages
git remote add origin https://github.com/panchi1225/Inspect-Pro.git 2>/dev/null || true
git push -f origin gh-pages

cd ../..

echo ""
echo "✅ デプロイ完了！"
echo ""
echo "📍 以下のURLでアクセス可能になります（数分後）:"
echo "   https://panchi1225.github.io/Inspect-Pro/"
echo ""
echo "⚙️  GitHub設定を確認してください:"
echo "   1. https://github.com/panchi1225/Inspect-Pro/settings/pages"
echo "   2. Source: 'Deploy from a branch' を選択"
echo "   3. Branch: 'gh-pages' / (root) を選択"
echo "   4. Save をクリック"
echo ""
