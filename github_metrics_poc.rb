#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'csv'
require 'optparse'
require 'date'
require 'uri'

class GitHubMetricsCollector
  def initialize(token, org)
    @token = token
    @org = org
    @base_url = 'https://api.github.com'
    @headers = {
      'Authorization' => "token #{@token}",
      'Accept' => 'application/vnd.github.v3+json',
      'User-Agent' => 'GitHubMetricsCollector/1.0'
    }
  end

  def collect_metrics(days = 30)
    since_date = (Date.today - days).iso8601
    
    puts "GitHub チームメトリクスを収集中..."
    puts "期間: 過去 #{days} 日間"
    puts "組織: #{@org}"
    
    repos = get_repositories
    puts "リポジトリ数: #{repos.length}"
    
    metrics = {
      'period' => "#{days}日間",
      'collected_at' => Time.now.iso8601,
      'organization' => @org,
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
    
    repos.each_with_index do |repo, index|
      repo_name = repo['name']
      puts "処理中 (#{index + 1}/#{repos.length}): #{repo_name}"
      
      prs = get_pull_requests(repo_name, since_date)
      commits = get_commits(repo_name, since_date)
      issues = get_issues(repo_name, since_date)
      
      merged_prs = prs.select { |pr| pr['merged_at'] }
      closed_issues = issues.select { |issue| issue['state'] == 'closed' }
      
      # 貢献者を収集
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
    
    # 全体の貢献者数を更新
    metrics['summary']['unique_contributors'] = metrics['summary']['unique_contributors'].length
    
    metrics
  end

  private

  def api_request(path, params = {})
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
    repos = []
    page = 1
    
    loop do
      data = api_request("/orgs/#{@org}/repos", { page: page, per_page: 100 })
      break if data.empty?
      
      repos.concat(data)
      page += 1
    end
    
    repos
  end

  def get_pull_requests(repo, since_date)
    prs = []
    page = 1
    
    loop do
      data = api_request("/repos/#{@org}/#{repo}/pulls", {
        state: 'all',
        since: since_date,
        sort: 'updated',
        direction: 'desc',
        page: page,
        per_page: 100
      })
      break if data.empty?
      
      prs.concat(data)
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
    
    loop do
      data = api_request("/repos/#{@org}/#{repo}/issues", {
        state: 'all',
        since: since_date,
        page: page,
        per_page: 100
      })
      break if data.empty?
      
      # プルリクエストを除外（GitHubではPRもissueとして扱われる）
      issues.concat(data.reject { |issue| issue.key?('pull_request') })
      page += 1
    end
    
    issues
  end
end

class MetricsExporter
  def self.export_json(metrics, filename)
    File.open(filename, 'w') do |file|
      file.write(JSON.pretty_generate(metrics))
    end
    puts "JSONファイルを保存しました: #{filename}"
  end

  def self.export_tsv(metrics, filename)
    CSV.open(filename, 'w', col_sep: "\t") do |csv|
      # ヘッダー行
      csv << [
        'リポジトリ名', 'プルリクエスト数', 'マージ済みPR数', 
        'コミット数', 'クローズ済みイシュー数', '貢献者数'
      ]
      
      # データ行
      metrics['repositories'].each do |repo|
        csv << [
          repo['name'],
          repo['pull_requests'],
          repo['merged_prs'],
          repo['commits'],
          repo['closed_issues'],
          repo['contributor_count']
        ]
      end
      
      # サマリー行
      csv << ['---', '---', '---', '---', '---', '---']
      csv << [
        '合計',
        metrics['summary']['total_pull_requests'],
        metrics['summary']['merged_pull_requests'],
        metrics['summary']['total_commits'],
        metrics['summary']['closed_issues'],
        metrics['summary']['unique_contributors']
      ]
    end
    puts "TSVファイルを保存しました: #{filename}"
  end
end

# メイン処理
def main
  options = {}
  
  OptionParser.new do |opts|
    opts.banner = "使用方法: #{$0} [オプション]"
    
    opts.on('--token TOKEN', 'GitHub Personal Access Token（必須）') do |token|
      options[:token] = token
    end
    
    opts.on('--org ORGANIZATION', '組織名（必須）') do |org|
      options[:org] = org
    end
    
    opts.on('--days DAYS', Integer, '収集期間（日数、デフォルト: 30）') do |days|
      options[:days] = days
    end
    
    opts.on('--format FORMAT', ['json', 'tsv', 'both'], '出力形式（json/tsv/both、デフォルト: both）') do |format|
      options[:format] = format
    end
    
    opts.on('--output PREFIX', '出力ファイル名のプレフィックス（デフォルト: metrics）') do |output|
      options[:output] = output
    end
    
    opts.on('-h', '--help', 'ヘルプを表示') do
      puts opts
      exit
    end
  end.parse!
  
  # 必須パラメータのチェック
  unless options[:token] && options[:org]
    puts "エラー: --token と --org は必須です"
    puts "使用例: #{$0} --token YOUR_TOKEN --org YOUR_ORG"
    exit 1
  end
  
  # デフォルト値設定
  options[:days] ||= 30
  options[:format] ||= 'both'
  options[:output] ||= 'metrics'
  
  begin
    collector = GitHubMetricsCollector.new(options[:token], options[:org])
    metrics = collector.collect_metrics(options[:days])
    
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    case options[:format]
    when 'json'
      MetricsExporter.export_json(metrics, "#{options[:output]}_#{timestamp}.json")
    when 'tsv'
      MetricsExporter.export_tsv(metrics, "#{options[:output]}_#{timestamp}.tsv")
    when 'both'
      MetricsExporter.export_json(metrics, "#{options[:output]}_#{timestamp}.json")
      MetricsExporter.export_tsv(metrics, "#{options[:output]}_#{timestamp}.tsv")
    end
    
    puts "\n=== 収集結果サマリー ==="
    puts "期間: #{metrics['period']}"
    puts "リポジトリ数: #{metrics['summary']['total_repositories']}"
    puts "プルリクエスト総数: #{metrics['summary']['total_pull_requests']}"
    puts "マージ済みPR数: #{metrics['summary']['merged_pull_requests']}"
    puts "コミット総数: #{metrics['summary']['total_commits']}"
    puts "クローズ済みイシュー数: #{metrics['summary']['closed_issues']}"
    puts "貢献者数: #{metrics['summary']['unique_contributors']}"
    
  rescue => e
    puts "エラーが発生しました: #{e.message}"
    exit 1
  end
end

if __FILE__ == $0
  main
end