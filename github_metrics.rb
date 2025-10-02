#!/usr/bin/env ruby

require 'optparse'
require_relative 'lib/github_metrics_collector'
require_relative 'lib/metrics_exporter'

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
    
    opts.on('--repo REPOSITORY', '特定のリポジトリ名（指定しない場合は組織全体）') do |repo|
      options[:repo] = repo
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
    collector = GitHubMetricsCollector.new(options[:token], options[:org], options[:repo])
    metrics = collector.collect_metrics(options[:days])
    
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    case options[:format]
    when 'json'
      MetricsExporter.export_json(metrics, "#{options[:output]}_#{timestamp}.json")
    when 'tsv'
      MetricsExporter.export_tsv(metrics, "#{options[:output]}_#{timestamp}.tsv")
      MetricsExporter.export_personal_tsv(metrics, "#{options[:output]}_personal_#{timestamp}.tsv")
    when 'both'
      MetricsExporter.export_json(metrics, "#{options[:output]}_#{timestamp}.json")
      MetricsExporter.export_tsv(metrics, "#{options[:output]}_#{timestamp}.tsv")
      MetricsExporter.export_personal_tsv(metrics, "#{options[:output]}_personal_#{timestamp}.tsv")
    end
    
  rescue => e
    puts "エラーが発生しました: #{e.message}"
    exit 1
  end
end

if __FILE__ == $0
  main
end