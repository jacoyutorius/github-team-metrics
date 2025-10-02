# GitHub チームメトリクス収集ツール

GitHub APIを使用してチームの開発スループットデータを収集し、JSON/TSV形式で出力するRubyツールです。

## 機能

- GitHub組織のリポジトリ一覧取得
- プルリクエスト統計（作成・マージ・クローズ数）
- コミット数の集計
- イシュー統計（作成・クローズ数）
- 貢献者数の計算
- JSON/TSV形式での結果出力

## 前提条件

- Ruby 3.0以上
- GitHub Personal Access Token
- 対象となるGitHub組織へのアクセス権限

## セットアップ

### 1. GitHub Personal Access Tokenの作成

1. GitHubにログインし、Settings > Developer settings > Personal access tokens > Tokens (classic) にアクセス
2. "Generate new token (classic)" をクリック
3. 以下のスコープを選択：
   - `repo` (リポジトリへの完全アクセス)
   - `read:org` (組織情報の読み取り)
4. トークンをコピーして安全に保存

### 2. スクリプトの実行権限設定

```bash
chmod +x github_metrics_poc.rb
```

## 使用方法

### 基本的な使用方法

```bash
ruby github_metrics_poc.rb --token YOUR_GITHUB_TOKEN --org YOUR_ORGANIZATION
```

### オプション

| オプション | 説明 | デフォルト値 |
|------------|------|--------------|
| `--token` | GitHub Personal Access Token（必須） | - |
| `--org` | 組織名（必須） | - |
| `--days` | 収集期間（日数） | 30 |
| `--format` | 出力形式（json/tsv/both） | both |
| `--output` | 出力ファイル名のプレフィックス | metrics |

### 使用例

```bash
# 過去30日間のデータをJSON・TSV両方で出力
ruby github_metrics_poc.rb --token ghp_xxxxxxxxxxxx --org your-company

# 過去7日間のデータをJSONのみで出力
ruby github_metrics_poc.rb --token ghp_xxxxxxxxxxxx --org your-company --days 7 --format json

# カスタムファイル名で出力
ruby github_metrics_poc.rb --token ghp_xxxxxxxxxxxx --org your-company --output team_report
```

## 出力ファイル

### JSON形式

```json
{
  "period": "30日間",
  "collected_at": "2025-01-15T10:30:00Z",
  "organization": "your-org",
  "summary": {
    "total_repositories": 15,
    "total_pull_requests": 124,
    "merged_pull_requests": 89,
    "total_commits": 456,
    "closed_issues": 67,
    "unique_contributors": 12
  },
  "repositories": [
    {
      "name": "repo-1",
      "pull_requests": 23,
      "merged_prs": 18,
      "commits": 89,
      "closed_issues": 12,
      "contributors": ["user1", "user2", "user3"],
      "contributor_count": 3
    }
  ]
}
```

### TSV形式

表計算ソフト（Excel、Google Sheetsなど）で開いて分析できる形式です。

```
リポジトリ名	プルリクエスト数	マージ済みPR数	コミット数	クローズ済みイシュー数	貢献者数
repo-1	23	18	89	12	3
repo-2	15	12	67	8	2
...
合計	124	89	456	67	12
```

## トラブルシューティング

### 認証エラー
```
認証エラー: GitHub トークンを確認してください
```
- トークンが正しく設定されているか確認
- トークンの有効期限をチェック
- 必要なスコープが付与されているか確認

### API制限エラー
```
API制限エラー: しばらく待ってから再実行してください
```
- GitHub APIの制限（5,000リクエスト/時）に達した場合
- 1時間待つか、対象期間を短くして再実行

### リソースが見つからない
```
リソースが見つかりません: 組織名を確認してください
```
- 組織名のスペルをチェック
- 組織へのアクセス権限を確認

## 注意事項

- GitHub APIの制限により、大規模な組織では実行に時間がかかる場合があります
- プライベートリポジトリにアクセスする場合は、適切な権限を持つトークンが必要です
- トークンは機密情報として適切に管理してください

## ライセンス

MIT License