require 'json'
require 'csv'

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
  
  def self.export_personal_tsv(metrics, filename)
    CSV.open(filename, 'w', col_sep: "\t") do |csv|
      # ヘッダー行
      csv << [
        'ユーザー名', 'PR作成数', 'PRマージ数', 'コミット数', 
        'イシュー解決数', '対象リポジトリ数', '活動リポジトリ'
      ]
      
      # 個人別データを貢献度順でソート
      sorted_users = metrics['personal_metrics'].sort_by do |user, data|
        # 総貢献度を計算（重み付き）
        -(data['pull_requests_created'] * 3 + 
          data['pull_requests_merged'] * 5 + 
          data['commits'] * 1 + 
          data['issues_closed'] * 2)
      end
      
      # データ行
      sorted_users.each do |user, data|
        csv << [
          user,
          data['pull_requests_created'],
          data['pull_requests_merged'],
          data['commits'],
          data['issues_closed'],
          data['repositories'].length,
          data['repositories'].join(', ')
        ]
      end
    end
    puts "個人別TSVファイルを保存しました: #{filename}"
  end
end