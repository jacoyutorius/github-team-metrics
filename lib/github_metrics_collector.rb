# frozen_string_literal: true

require 'net/http'
require 'json'
require 'date'
require 'uri'
require 'set'

class GitHubMetricsCollector
  def initialize(token, org, repo = nil)
    @token = token
    @org = org
    @repo = repo
    @base_url = 'https://api.github.com'
    @headers = {
      'Authorization' => "token #{@token}",
      'Accept' => 'application/vnd.github.v3+json',
      'User-Agent' => 'GitHubMetricsCollector/1.0'
    }
    @api_call_count = 0
  end

  def collect_metrics(days = 30)
    since_date = (Date.today - days).iso8601
    print_collection_header(days)

    repos = fetch_target_repositories
    metrics = initialize_metrics(days, repos.length)
    personal_metrics = initialize_personal_metrics

    repos.each_with_index do |repo, index|
      process_repository(repo, index, repos.length, since_date, metrics, personal_metrics)
    end

    finalize_metrics(metrics, personal_metrics)

    puts "\n\n=== 収集結果サマリー ==="
    puts "期間: #{metrics['period']}"
    puts "総 API呼び出し回数: #{@api_call_count}回"
    puts "リポジトリ数: #{metrics['summary']['total_repositories']}"
    puts "プルリクエスト総数: #{metrics['summary']['total_pull_requests']}"
    puts "マージ済みPR数: #{metrics['summary']['merged_pull_requests']}"
    puts "コミット総数: #{metrics['summary']['total_commits']}"
    puts "クローズ済みイシュー数: #{metrics['summary']['closed_issues']}"
    puts "貢献者数: #{metrics['summary']['unique_contributors']}"
    puts "個人別メトリクス: #{metrics['personal_metrics'].length}人"

    metrics
  end

  private

  def api_request(path, params = {})
    @api_call_count += 1

    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params) unless params.empty?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    @headers.each { |key, value| request[key] = value }

    response = http.request(request)

    case response.code.to_i
    when 200
      JSON.parse(response.body)
    when 401
      raise '認証エラー: GitHub トークンを確認してください'
    when 403
      raise 'API制限エラー: しばらく待ってから再実行してください'
    when 404
      raise 'リソースが見つかりません: 組織名を確認してください'
    else
      raise "APIエラー: #{response.code} - #{response.body}"
    end
  end

  def print_collection_header(days)
    puts 'GitHub チームメトリクスを収集中...'
    puts "期間: 過去 #{days} 日間"
  end

  def fetch_target_repositories
    if @repo
      puts "リポジトリ: #{@org}/#{@repo}"
      [{ 'name' => @repo }]
    else
      puts "組織: #{@org}"
      repos = repositories
      puts "リポジトリ数: #{repos.length}"
      repos
    end
  end

  def initialize_metrics(days, repo_count)
    {
      'period' => "#{days}日間",
      'collected_at' => Time.now.iso8601,
      'organization' => @org,
      'repository' => @repo,
      'summary' => {
        'total_repositories' => repo_count,
        'total_pull_requests' => 0,
        'merged_pull_requests' => 0,
        'total_commits' => 0,
        'closed_issues' => 0,
        'unique_contributors' => Set.new
      },
      'repositories' => []
    }
  end

  def initialize_personal_metrics
    Hash.new do |h, k|
      h[k] = {
        'pull_requests_created' => 0,
        'pull_requests_merged' => 0,
        'commits' => 0,
        'issues_closed' => 0,
        'pr_comments' => 0,
        'review_comments' => 0,
        'repositories' => Set.new
      }
    end
  end

  def process_repository(repo, index, total_repos, since_date, metrics, personal_metrics)
    repo_name = repo['name']
    print_repository_progress(repo_name, index, total_repos)

    repo_data = fetch_repository_data(repo_name, since_date)
    aggregate_personal_metrics(repo_name, repo_data, personal_metrics)
    update_metrics(repo_name, repo_data, metrics)
  end

  def print_repository_progress(repo_name, index, total)
    progress = ((index + 1).to_f / total * 100).round(1)
    puts "\n=== 処理中 (#{index + 1}/#{total}, #{progress}%) ==="
    puts "リポジトリ: #{repo_name}"
  end

  def fetch_repository_data(repo_name, since_date)
    print '  PR情報を取得中...'
    prs = get_pull_requests(repo_name, since_date)
    puts " #{prs.length}件 (API呼び出し: #{@api_call_count}回)"

    print '  コミット情報を取得中...'
    commits = get_commits(repo_name, since_date)
    puts " #{commits.length}件 (API呼び出し: #{@api_call_count}回)"

    print '  イシュー情報を取得中...'
    issues = get_issues(repo_name, since_date)
    puts " #{issues.length}件 (API呼び出し: #{@api_call_count}回)"

    print '  コメント情報を取得中...'
    pr_comments = get_pr_comments(repo_name, prs)
    review_comments = get_review_comments(repo_name, prs)
    puts " PR: #{pr_comments.length}件, レビュー: #{review_comments.length}件 (API呼び出し: #{@api_call_count}回)"

    {
      prs: prs,
      commits: commits,
      issues: issues,
      pr_comments: pr_comments,
      review_comments: review_comments,
      merged_prs: prs.select { |pr| pr['merged_at'] },
      closed_issues: issues.select { |issue| issue['state'] == 'closed' }
    }
  end

  def aggregate_personal_metrics(repo_name, repo_data, personal_metrics)
    print '  個人別メトリクスを集計中...'

    aggregate_pr_metrics(repo_name, repo_data[:prs], personal_metrics)
    aggregate_commit_metrics(repo_name, repo_data[:commits], personal_metrics)
    aggregate_issue_metrics(repo_name, repo_data[:closed_issues], personal_metrics)
    aggregate_comment_metrics(repo_name, repo_data[:pr_comments], repo_data[:review_comments], personal_metrics)

    puts ' 完了'
    total_comments = repo_data[:pr_comments].length + repo_data[:review_comments].length
    puts "  → PR: #{repo_data[:prs].length}件, コミット: #{repo_data[:commits].length}件, " \
         "イシュー: #{repo_data[:issues].length}件, コメント: #{total_comments}件"
  end

  def aggregate_pr_metrics(repo_name, prs, personal_metrics)
    prs.each do |pr|
      next unless pr['user']&.[]('login')

      user = pr['user']['login']
      personal_metrics[user]['pull_requests_created'] += 1
      personal_metrics[user]['repositories'].add(repo_name)
      personal_metrics[user]['pull_requests_merged'] += 1 if pr['merged_at']
    end
  end

  def aggregate_commit_metrics(repo_name, commits, personal_metrics)
    commits.each do |commit|
      next unless commit['author']&.[]('login')

      user = commit['author']['login']
      personal_metrics[user]['commits'] += 1
      personal_metrics[user]['repositories'].add(repo_name)
    end
  end

  def aggregate_issue_metrics(repo_name, closed_issues, personal_metrics)
    closed_issues.each do |issue|
      user = issue.dig('assignee', 'login') || (issue.dig('user', 'login') if issue['state'] == 'closed')
      next unless user

      personal_metrics[user]['issues_closed'] += 1
      personal_metrics[user]['repositories'].add(repo_name)
    end
  end

  def aggregate_comment_metrics(repo_name, pr_comments, review_comments, personal_metrics)
    pr_comments.each do |comment|
      next unless comment['user']&.[]('login')

      user = comment['user']['login']
      personal_metrics[user]['pr_comments'] += 1
      personal_metrics[user]['repositories'].add(repo_name)
    end

    review_comments.each do |comment|
      next unless comment['user']&.[]('login')

      user = comment['user']['login']
      personal_metrics[user]['review_comments'] += 1
      personal_metrics[user]['repositories'].add(repo_name)
    end
  end

  def update_metrics(repo_name, repo_data, metrics)
    contributors = collect_contributors(repo_data[:prs], repo_data[:commits])

    repo_metrics = {
      'name' => repo_name,
      'pull_requests' => repo_data[:prs].length,
      'merged_prs' => repo_data[:merged_prs].length,
      'commits' => repo_data[:commits].length,
      'closed_issues' => repo_data[:closed_issues].length,
      'contributors' => contributors.to_a,
      'contributor_count' => contributors.length
    }

    metrics['repositories'] << repo_metrics
    metrics['summary']['total_pull_requests'] += repo_data[:prs].length
    metrics['summary']['merged_pull_requests'] += repo_data[:merged_prs].length
    metrics['summary']['total_commits'] += repo_data[:commits].length
    metrics['summary']['closed_issues'] += repo_data[:closed_issues].length
    metrics['summary']['unique_contributors'].merge(contributors)
  end

  def collect_contributors(prs, commits)
    contributors = Set.new
    prs.each { |pr| contributors.add(pr['user']['login']) if pr['user'] }
    commits.each { |commit| contributors.add(commit['author']['login']) if commit['author'] }
    contributors
  end

  def finalize_metrics(metrics, personal_metrics)
    metrics['personal_metrics'] = personal_metrics.transform_values do |user_data|
      user_data.merge('repositories' => user_data['repositories'].to_a)
    end

    metrics['summary']['unique_contributors'] = metrics['summary']['unique_contributors'].length
    metrics
  end

  def repositories
    puts '組織のリポジトリ一覧を取得中...'
    repos = []
    page = 1

    loop do
      data = api_request("/orgs/#{@org}/repos", { page: page, per_page: 100 })
      break if data.empty?

      repos.concat(data)
      puts "  ページ #{page}: #{data.length}件取得 (累計: #{repos.length}件)"
      page += 1
    end

    repos
  end

  def get_pull_requests(repo, since_date)
    prs = []
    page = 1
    target_date = Date.parse(since_date)

    loop do
      data = api_request("/repos/#{@org}/#{repo}/pulls", {
                           state: 'all',
                           sort: 'created',
                           direction: 'desc',
                           page: page,
                           per_page: 100
                         })
      break if data.empty?

      # 作成日でフィルタリング
      filtered_data = data.select do |pr|
        created_date = Date.parse(pr['created_at'])
        created_date >= target_date
      end

      prs.concat(filtered_data)

      # 最後のPRの作成日が期間外になったら終了
      break if data.last && Date.parse(data.last['created_at']) < target_date

      page += 1
    end

    prs
  end

  def get_commits(repo, since_date)
    commits = []
    page = 1

    loop do
      data = api_request("/repos/#{@org}/#{repo}/commits", {
                           since: since_date,
                           page: page,
                           per_page: 100
                         })
      break if data.empty?

      commits.concat(data)
      page += 1
    end

    commits
  end

  def get_issues(repo, since_date)
    issues = []
    page = 1
    target_date = Date.parse(since_date)

    loop do
      data = api_request("/repos/#{@org}/#{repo}/issues", {
                           state: 'all',
                           sort: 'created',
                           direction: 'desc',
                           page: page,
                           per_page: 100
                         })
      break if data.empty?

      # プルリクエストを除外し、作成日でフィルタリング
      filtered_data = data.reject { |issue| issue.key?('pull_request') }.select do |issue|
        created_date = Date.parse(issue['created_at'])
        created_date >= target_date
      end

      issues.concat(filtered_data)

      # 最後のイシューの作成日が期間外になったら終了
      last_issue = data.reject { |issue| issue.key?('pull_request') }.last
      break if last_issue && Date.parse(last_issue['created_at']) < target_date

      page += 1
    end

    issues
  end

  def get_pr_comments(repo, prs)
    comments = []

    prs.each do |pr|
      pr_number = pr['number']
      page = 1

      # PR本体のコメントを取得
      loop do
        data = api_request("/repos/#{@org}/#{repo}/issues/#{pr_number}/comments", {
                             page: page,
                             per_page: 100
                           })
        break if data.empty?

        comments.concat(data)
        page += 1
      rescue StandardError
        # エラー時はスキップ
        break
      end
    end

    comments
  end

  def get_review_comments(repo, prs)
    comments = []

    prs.each do |pr|
      pr_number = pr['number']
      page = 1

      # PRのレビューコメントを取得
      loop do
        data = api_request("/repos/#{@org}/#{repo}/pulls/#{pr_number}/comments", {
                             page: page,
                             per_page: 100
                           })
        break if data.empty?

        comments.concat(data)
        page += 1
      rescue StandardError
        # エラー時はスキップ
        break
      end
    end

    comments
  end
end
