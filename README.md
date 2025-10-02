# GitHub チームメトリクス収集ツール

GitHub APIを使用してチームの開発スループットデータを収集し、JSON/TSV形式で出力するRubyツールです。

## 機能

- GitHub組織のリポジトリ一覧取得
- プルリクエスト統計（作成・マージ・クローズ数）
- コミット数の集計
- イシュー統計（作成・クローズ数）
- 貢献者数の計算
- **個人別メトリクス集計**（PR作成・マージ数、コミット数、イシュー解決数、コメント数）
- **コメント統計**（PRコメント・レビューコメント）
- JSON/TSV形式での結果出力（個人別TSVも含む）

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
chmod +x github_metrics.rb
```

## メトリクス算出方法

### 収集対象期間
- `--days`オプションで指定した日数分（デフォルト: 30日間）
- 基準日: 実行日からさかのぼって計算

### プルリクエスト数
- **対象**: 指定期間内に**作成**されたプルリクエスト
- **算出方法**: GitHub API `/repos/{org}/{repo}/pulls` で `created_at` が期間内のPRを取得
- **状態**: 全ての状態（open, closed, merged）を含む
- **注意**: PRの更新日ではなく作成日で判定

### マージ済みPR数  
- **対象**: 上記で取得したPRのうち、`merged_at` フィールドが存在するもの
- **算出方法**: `merged_at` が `null` でないPRをカウント
- **注意**: 期間外にマージされたPRも、期間内に作成されていれば含まれる

### コミット数
- **対象**: 指定期間内に**コミット**されたコミット
- **算出方法**: GitHub API `/repos/{org}/{repo}/commits` で `since` パラメータを使用
- **基準**: コミット日時（`commit.committer.date`）
- **注意**: マージコミットも含む

### クローズ済みイシュー数
- **対象**: 指定期間内に**作成**されたイシューのうち、`state` が `closed` のもの
- **算出方法**: GitHub API `/repos/{org}/{repo}/issues` で `created_at` が期間内かつ `state: closed`
- **除外**: プルリクエスト（GitHubではPRもissueとして扱われるため）
- **注意**: イシューのクローズ日ではなく作成日で判定

### コメント数
- **PRコメント数**: 指定期間内に作成されたPRに対するコメント
- **算出方法**: GitHub API `/repos/{org}/{repo}/issues/{pr_number}/comments` でPRごとのコメントを取得
- **対象**: PR本体へのコメント（レビューコメントは別途）
- **基準**: コメント作成者（`user.login`）

### レビューコメント数
- **対象**: 指定期間内に作成されたPRに対するレビューコメント
- **算出方法**: GitHub API `/repos/{org}/{repo}/pulls/{pr_number}/comments` でPRごとのレビューコメントを取得
- **基準**: コメント作成者（`user.login`）
- **特徴**: コードの特定行に対するレビューコメント（差分コメント）

### 個人別メトリクス
- **PR作成数**: 各ユーザーが作成したPR数（`user.login` 基準）
- **PRマージ数**: 各ユーザーが作成したPRのうちマージされた数
- **コミット数**: 各ユーザーのコミット数（`author.login` 基準）
- **イシュー解決数**: 各ユーザーがアサインされたまたは作成したクローズ済みイシュー数
- **PRコメント数**: 各ユーザーが投稿したPRコメント数
- **レビューコメント数**: 各ユーザーが投稿したレビューコメント数
- **貢献度ソート**: PR作成×3 + PRマージ×5 + コミット×1 + イシュー解決×2 + PRコメント×1 + レビューコメント×2 の重み付きスコア

## 使用方法

### 基本的な使用方法

```bash
# 組織全体のデータを収集
ruby github_metrics.rb --token YOUR_GITHUB_TOKEN --org YOUR_ORGANIZATION

# 特定のリポジトリのみ収集（高速）
ruby github_metrics.rb --token YOUR_GITHUB_TOKEN --org YOUR_ORGANIZATION --repo REPOSITORY_NAME
```

### オプション

| オプション | 説明 | デフォルト値 |
|------------|------|--------------|
| `--token` | GitHub Personal Access Token（必須） | - |
| `--org` | 組織名（必須） | - |
| `--repo` | 特定のリポジトリ名（指定しない場合は組織全体） | - |
| `--days` | 収集期間（日数） | 30 |
| `--format` | 出力形式（json/tsv/both） | both |
| `--output` | 出力ファイル名のプレフィックス | metrics |

### 使用例

```bash
# 組織全体の過去30日間のデータをJSON・TSV両方で出力
ruby github_metrics.rb --token ghp_xxxxxxxxxxxx --org your-company

# 特定のリポジトリのみ収集（処理時間短縮）
ruby github_metrics.rb --token ghp_xxxxxxxxxxxx --org your-company --repo important-project

# 過去7日間のデータをJSONのみで出力
ruby github_metrics.rb --token ghp_xxxxxxxxxxxx --org your-company --repo my-repo --days 7 --format json

# カスタムファイル名で出力
ruby github_metrics.rb --token ghp_xxxxxxxxxxxx --org your-company --repo api-server --output backend_metrics
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