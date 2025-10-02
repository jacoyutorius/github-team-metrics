# GitHub Team Metrics Viewer

Vue3 + TypeScript + Chart.jsで構築された、GitHubチームメトリクスの可視化ツールです。

## 機能

- JSONファイルのドラッグ&ドロップアップロード
- サマリーカード表示（PR、コミット、イシュー、貢献者数）
- 個人別メトリクスのグラフ表示：
  - PR作成数
  - PRマージ数
  - コミット数
  - レビューコメント数
  - 貢献度スコア
  - 活動内訳（上位5名の積み上げグラフ）

## セットアップ

```bash
# 依存関係のインストール
npm install

# 開発サーバーの起動
npm run dev

# ビルド
npm run build
```

## 使い方

1. 開発サーバーを起動
2. ブラウザで http://localhost:5173 を開く
3. `github_metrics.rb` で生成したJSONファイルをアップロード
4. メトリクスのダッシュボードが表示されます

## 技術スタック

- **Vue 3** - Composition API
- **TypeScript** - 型安全性
- **Vite** - 高速ビルドツール
- **Chart.js** - グラフ描画
- **vue-chartjs** - Vue用Chart.jsラッパー
