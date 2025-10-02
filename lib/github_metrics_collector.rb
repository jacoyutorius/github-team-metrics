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
    
    puts "GitHub チームメトリクスを収集中..."
    puts "期間: 過去 #{days} 日間"
    
    if @repo
      puts "リポジトリ: #{@org}/#{@repo}"
      repos = [{'name' => @repo}]
    else
      puts "組織: #{@org}"
      repos = get_repositories
      puts "リポジトリ数: #{repos.length}"
    end
    
    metrics = {
      'period' => "#{days}日間",
      'collected_at' => Time.now.iso8601,
      'organization' => @org,
      'repository' => @repo,
      'summary' => {
        'total_repositories' => repos.length,
        'total_pull_requests' => 0,
        'merged_pull_requests' => 0,
        'total_commits' => 0,
        'closed_issues' => 0,
        'unique_contributors' => Set.new
      },
      'repositories' => []
    }
    
    # 個人別メトリクスを収集
    personal_metrics = Hash.new { |h, k| h[k] = {
      'pull_requests_created' => 0,
      'pull_requests_merged' => 0,
      'commits' => 0,
      'issues_closed' => 0,
      'repositories' => Set.new
    }}
    
    repos.each_with_index do |repo, index|
      repo_name = repo['name']
      progress = ((index + 1).to_f / repos.length * 100).round(1)
      puts "\n=== 処理中 (#{index + 1}/#{repos.length}, #{progress}%) ===" 
      puts "リポジトリ: #{repo_name}"
      
      print "  PR情報を取得中..."
      prs = get_pull_requests(repo_name, since_date)
      puts " #{prs.length}件 (API呼び出し: #{@api_call_count}回)"
      
      print "  コミット情報を取得中..."
      commits = get_commits(repo_name, since_date)
      puts " #{commits.length}件 (API呼び出し: #{@api_call_count}回)"
      
      print "  イシュー情報を取得中..."
      issues = get_issues(repo_name, since_date)
      puts " #{issues.length}件 (API呼び出し: #{@api_call_count}回)"
      
      merged_prs = prs.select { |pr| pr['merged_at'] }
      closed_issues = issues.select { |issue| issue['state'] == 'closed' }
      
      print "  個人別メトリクスを集計中..."
      
      # 個人別PR統計
      prs.each do |pr|
        if pr['user'] && pr['user']['login']
          user = pr['user']['login']
          personal_metrics[user]['pull_requests_created'] += 1
          personal_metrics[user]['repositories'].add(repo_name)
          
          if pr['merged_at']
            personal_metrics[user]['pull_requests_merged'] += 1
          end
        end
      end
      
      # 個人別コミット統計
      commits.each do |commit|
        if commit['author'] && commit['author']['login']
          user = commit['author']['login']
          personal_metrics[user]['commits'] += 1
          personal_metrics[user]['repositories'].add(repo_name)
        end
      end
      
      # 個人別イシュー統計
      closed_issues.each do |issue|
        if issue['assignee'] && issue['assignee']['login']
          user = issue['assignee']['login']
          personal_metrics[user]['issues_closed'] += 1
          personal_metrics[user]['repositories'].add(repo_name)
        elsif issue['user'] && issue['user']['login'] && issue['state'] == 'closed'
          user = issue['user']['login']
          personal_metrics[user]['issues_closed'] += 1
          personal_metrics[user]['repositories'].add(repo_name)
        end
      end
      
      puts " 完了"
      puts "  → PR: #{prs.length}件, コミット: #{commits.length}件, イシュー: #{issues.length}件"
      
      # 貢献者を収集（後方互換性のため）
      contributors = Set.new
      prs.each { |pr| contributors.add(pr['user']['login']) if pr['user'] }
      commits.each { |commit| contributors.add(commit['author']['login']) if commit['author'] }
      
      repo_metrics = {
        'name' => repo_name,
        'pull_requests' => prs.length,
        'merged_prs' => merged_prs.length,
        'commits' => commits.length,
        'closed_issues' => closed_issues.length,
        'contributors' => contributors.to_a,
        'contributor_count' => contributors.length
      }
      
      metrics['repositories'] << repo_metrics
      metrics['summary']['total_pull_requests'] += prs.length
      metrics['summary']['merged_pull_requests'] += merged_prs.length
      metrics['summary']['total_commits'] += commits.length
      metrics['summary']['closed_issues'] += closed_issues.length
      metrics['summary']['unique_contributors'].merge(contributors)
    end
    
    # 個人別メトリクスをメトリクスに追加
    metrics['personal_metrics'] = personal_metrics.transform_values do |user_data|
      user_data.merge('repositories' => user_data['repositories'].to_a)
    end
    
    # 全体の貢献者数を更新
    metrics['summary']['unique_contributors'] = metrics['summary']['unique_contributors'].length
    
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
      raise "認証エラー: GitHub トークンを確認してください"
    when 403
      raise "API制限エラー: しばらく待ってから再実行してください"
    when 404
      raise "リソースが見つかりません: 組織名を確認してください"
    else
      raise "APIエラー: #{response.code} - #{response.body}"
    end
  end

  def get_repositories
    puts "組織のリポジトリ一覧を取得中..."
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
      if data.last && Date.parse(data.last['created_at']) < target_date
        break
      end
      
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
      if last_issue && Date.parse(last_issue['created_at']) < target_date
        break
      end
      
      page += 1
    end
    
    issues
  end
end