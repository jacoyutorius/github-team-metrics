# Docker を使った実行方法

このプロジェクトはDockerとDocker Composeを使って簡単に実行できます。

## 前提条件

- Docker
- Docker Compose

## セットアップ

1. 環境変数ファイルを作成

```bash
cp .env.example .env
```

2. `.env` ファイルを編集してGitHub認証情報を設定

```bash
GITHUB_TOKEN=your_github_token_here
GITHUB_ORG=your_organization_name
DAYS=30
```

## 使い方

### メトリクスの収集

```bash
# メトリクスを収集
docker compose --profile collect up metrics-collector

# バックグラウンドで実行
docker compose --profile collect up -d metrics-collector

# 収集後にコンテナを自動削除
docker compose --profile collect run --rm metrics-collector
```

収集されたメトリクスは `output/` ディレクトリに保存されます。

### メトリクスビューアーの起動

```bash
# ビューアーを起動
docker compose --profile viewer up metrics-viewer

# バックグラウンドで実行
docker compose --profile viewer up -d metrics-viewer
```

ブラウザで http://localhost:4173 にアクセスしてメトリクスを表示できます。

### カスタムパラメータでメトリクス収集

```bash
docker compose --profile collect run --rm metrics-collector \
  --token YOUR_TOKEN \
  --org YOUR_ORG \
  --days 60 \
  --format both \
  --output /app/output/custom_metrics
```

### 両方を同時に起動

```bash
docker compose --profile collect --profile viewer up
```

## クリーンアップ

```bash
# コンテナを停止
docker compose down

# イメージも削除
docker compose down --rmi all

# ボリュームも削除
docker compose down -v
```

## トラブルシューティング

### 権限エラーが発生する場合

`output/` ディレクトリの権限を確認してください：

```bash
mkdir -p output
chmod 777 output
```

### イメージを再ビルドする場合

```bash
docker compose build --no-cache
```
