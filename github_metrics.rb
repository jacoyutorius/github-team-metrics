#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require_relative 'lib/github_metrics_collector'
require_relative 'lib/metrics_exporter'

# コマンドラインオプションをパースする
def parse_options
  options = {}

  OptionParser.new do |opts|
    opts.banner = "使用方法: #{$PROGRAM_NAME} [オプション]"

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

    opts.on('--format FORMAT', %w[json tsv both], '出力形式（json/tsv/both、デフォルト: both）') do |format|
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

  options
end

# 必須パラメータを検証する
def validate_options!(options)
  return if options[:token] && options[:org]

  puts 'エラー: --token と --org は必須です'
  puts "使用例: #{$PROGRAM_NAME} --token YOUR_TOKEN --org YOUR_ORG"
  exit 1
end

# デフォルト値を設定する
def apply_defaults(options)
  options[:days] ||= 30
  options[:format] ||= 'both'
  options[:output] ||= 'metrics'
end

# メトリクスをエクスポートする
def export_metrics(metrics, format, output_prefix, timestamp)
  case format
  when 'json'
    MetricsExporter.export_json(metrics, "#{output_prefix}_#{timestamp}.json")
  when 'tsv'
    MetricsExporter.export_tsv(metrics, "#{output_prefix}_#{timestamp}.tsv")
    MetricsExporter.export_personal_tsv(metrics, "#{output_prefix}_personal_#{timestamp}.tsv")
  when 'both'
    MetricsExporter.export_json(metrics, "#{output_prefix}_#{timestamp}.json")
    MetricsExporter.export_tsv(metrics, "#{output_prefix}_#{timestamp}.tsv")
    MetricsExporter.export_personal_tsv(metrics, "#{output_prefix}_personal_#{timestamp}.tsv")
  end
end

# メイン処理
def main
  options = parse_options
  validate_options!(options)
  apply_defaults(options)

  collector = GitHubMetricsCollector.new(options[:token], options[:org], options[:repo])
  metrics = collector.collect_metrics(options[:days])

  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  export_metrics(metrics, options[:format], options[:output], timestamp)
rescue StandardError => e
  puts "エラーが発生しました: #{e.message}"
  exit 1
end

main if __FILE__ == $PROGRAM_NAME
