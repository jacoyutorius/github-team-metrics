# GitHub チームメトリクス収集 PoC 要件（Ruby版）

## 目的
開発チームのスループット向上への貢献を示すため、GitHub APIからチームの基本的な生産性データを収集し、ファイル出力するPoCをRubyで作成する。

## 機能要件（PoC版）

### 1. データ収集
- GitHub APIを使用してチーム/組織のデータを取得
- 収集対象データ：
  - プルリクエスト数（作成・マージ・クローズ）
  - コミット数
  - イシュー数（作成・クローズ）
  - 貢献者数
  - レビュー処理時間（基本統計）

### 2. 期間指定
- デフォルト：過去30日間
- コマンドライン引数で期間変更可能（7日、30日、90日）

### 3. 出力形式
- JSON形式：構造化データとして保存
- TSV形式：表計算ソフトでの分析用

### 4. 必要な情報
- GitHub Personal Access Token
- Organization名 または Repository名

## 技術仕様（Ruby版）

### 言語・ライブラリ
- Ruby 3.0+
- `net/http`（GitHub API連携）
- `json`（JSON処理）
- `csv`（TSV出力）
- `optparse`（コマンドライン引数解析）
- `octokit` gem（GitHub API専用ライブラリ、オプション）

### 実行方法
```bash
ruby github_metrics_poc.rb --token YOUR_TOKEN --org ORGANIZATION_NAME --days 30 --format json
```

### 出力データ例
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
      "contributors": 5
    }
  ]
}
```

### Gemfile（必要に応じて）
```ruby
source 'https://rubygems.org'

gem 'octokit'
gem 'csv'
```

## 成功条件
- [ ] GitHub APIからデータが正常に取得できる
- [ ] JSONファイルとTSVファイルが生成される
- [ ] エラーハンドリングが適切に動作する
- [ ] 合理的な時間内で実行完了する

## 制約事項
- GitHub API制限（5,000リクエスト/時）を考慮
- 認証エラー時の適切なメッセージ表示
- 大量データ処理時のメモリ使用量に注意