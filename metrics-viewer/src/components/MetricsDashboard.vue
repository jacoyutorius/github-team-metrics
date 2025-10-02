<template>
  <div class="dashboard">
    <div class="header">
      <h1>GitHub チームメトリクス</h1>
      <div class="meta-info">
        <span>組織: {{ metrics.organization }}</span>
        <span v-if="metrics.repository">リポジトリ: {{ metrics.repository }}</span>
        <span>期間: {{ metrics.period }}</span>
      </div>
    </div>

    <div class="summary-cards">
      <div class="card">
        <div class="card-title">プルリクエスト</div>
        <div class="card-value">{{ metrics.summary.total_pull_requests }}</div>
        <div class="card-subtitle">マージ済み: {{ metrics.summary.merged_pull_requests }}</div>
      </div>
      <div class="card">
        <div class="card-title">コミット</div>
        <div class="card-value">{{ metrics.summary.total_commits }}</div>
      </div>
      <div class="card">
        <div class="card-title">クローズ済みイシュー</div>
        <div class="card-value">{{ metrics.summary.closed_issues }}</div>
      </div>
      <div class="card">
        <div class="card-title">貢献者</div>
        <div class="card-value">{{ metrics.summary.unique_contributors }}</div>
      </div>
    </div>

    <div class="charts-grid">
      <div class="chart-container">
        <h2>個人別PR作成数</h2>
        <Bar :data="prCreatedChartData" :options="chartOptions" />
      </div>

      <div class="chart-container">
        <h2>個人別PRマージ数</h2>
        <Bar :data="prMergedChartData" :options="chartOptions" />
      </div>

      <div class="chart-container">
        <h2>個人別コミット数</h2>
        <Bar :data="commitsChartData" :options="chartOptions" />
      </div>

      <div class="chart-container">
        <h2>個人別レビューコメント数</h2>
        <Bar :data="reviewCommentsChartData" :options="chartOptions" />
      </div>

      <div class="chart-container">
        <h2>個人別貢献度スコア</h2>
        <div class="score-formula">
          <span class="formula-label">算出方法:</span>
          <code>PR作成×3 + PRマージ×5 + コミット×1 + イシュー解決×2 + PRコメント×1 + レビューコメント×2</code>
        </div>
        <Bar :data="contributionScoreChartData" :options="chartOptions" />
      </div>

      <div class="chart-container">
        <h2>活動内訳（上位5名）</h2>
        <Bar :data="activityBreakdownChartData" :options="stackedChartOptions" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Bar } from 'vue-chartjs'
import {
  Chart as ChartJS,
  Title,
  Tooltip,
  Legend,
  BarElement,
  CategoryScale,
  LinearScale
} from 'chart.js'
import type { GitHubMetrics } from '../types/metrics'

ChartJS.register(Title, Tooltip, Legend, BarElement, CategoryScale, LinearScale)

const props = defineProps<{
  metrics: GitHubMetrics
}>()

// 個人メトリクスを貢献度スコアでソート
const sortedPersonalMetrics = computed(() => {
  return Object.entries(props.metrics.personal_metrics)
    .map(([name, data]) => ({
      name,
      ...data,
      score:
        data.pull_requests_created * 3 +
        data.pull_requests_merged * 5 +
        data.commits * 1 +
        data.issues_closed * 2 +
        data.pr_comments * 1 +
        data.review_comments * 2
    }))
    .sort((a, b) => b.score - a.score)
})

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      display: false
    }
  }
}

const stackedChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      display: true,
      position: 'top' as const
    }
  },
  scales: {
    x: {
      stacked: true
    },
    y: {
      stacked: true
    }
  }
}

const prCreatedChartData = computed(() => ({
  labels: sortedPersonalMetrics.value.map((m) => m.name),
  datasets: [
    {
      label: 'PR作成数',
      data: sortedPersonalMetrics.value.map((m) => m.pull_requests_created),
      backgroundColor: '#4299e1'
    }
  ]
}))

const prMergedChartData = computed(() => ({
  labels: sortedPersonalMetrics.value.map((m) => m.name),
  datasets: [
    {
      label: 'PRマージ数',
      data: sortedPersonalMetrics.value.map((m) => m.pull_requests_merged),
      backgroundColor: '#48bb78'
    }
  ]
}))

const commitsChartData = computed(() => ({
  labels: sortedPersonalMetrics.value.map((m) => m.name),
  datasets: [
    {
      label: 'コミット数',
      data: sortedPersonalMetrics.value.map((m) => m.commits),
      backgroundColor: '#ed8936'
    }
  ]
}))

const reviewCommentsChartData = computed(() => ({
  labels: sortedPersonalMetrics.value.map((m) => m.name),
  datasets: [
    {
      label: 'レビューコメント数',
      data: sortedPersonalMetrics.value.map((m) => m.review_comments),
      backgroundColor: '#9f7aea'
    }
  ]
}))

const contributionScoreChartData = computed(() => ({
  labels: sortedPersonalMetrics.value.map((m) => m.name),
  datasets: [
    {
      label: '貢献度スコア',
      data: sortedPersonalMetrics.value.map((m) => m.score),
      backgroundColor: '#f56565'
    }
  ]
}))

const activityBreakdownChartData = computed(() => {
  const topContributors = sortedPersonalMetrics.value.slice(0, 5)
  return {
    labels: topContributors.map((m) => m.name),
    datasets: [
      {
        label: 'PR作成',
        data: topContributors.map((m) => m.pull_requests_created),
        backgroundColor: '#4299e1'
      },
      {
        label: 'PRマージ',
        data: topContributors.map((m) => m.pull_requests_merged),
        backgroundColor: '#48bb78'
      },
      {
        label: 'コミット',
        data: topContributors.map((m) => m.commits),
        backgroundColor: '#ed8936'
      },
      {
        label: 'レビューコメント',
        data: topContributors.map((m) => m.review_comments),
        backgroundColor: '#9f7aea'
      },
      {
        label: 'PRコメント',
        data: topContributors.map((m) => m.pr_comments),
        backgroundColor: '#ecc94b'
      }
    ]
  }
})
</script>

<style scoped>
.dashboard {
  max-width: 1400px;
  margin: 0 auto;
  padding: 2rem;
}

.header {
  margin-bottom: 2rem;
}

.header h1 {
  margin: 0 0 0.5rem 0;
  font-size: 2rem;
  color: #2d3748;
}

.meta-info {
  display: flex;
  gap: 1.5rem;
  color: #718096;
  font-size: 0.9rem;
}

.summary-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.card {
  background: white;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.card-title {
  font-size: 0.875rem;
  color: #718096;
  margin-bottom: 0.5rem;
}

.card-value {
  font-size: 2rem;
  font-weight: bold;
  color: #2d3748;
}

.card-subtitle {
  font-size: 0.875rem;
  color: #a0aec0;
  margin-top: 0.25rem;
}

.charts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
  gap: 2rem;
}

.chart-container {
  background: white;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  height: 350px;
}

.chart-container h2 {
  margin: 0 0 1rem 0;
  font-size: 1.125rem;
  color: #2d3748;
}

.score-formula {
  margin-bottom: 1rem;
  padding: 0.75rem;
  background-color: #edf2f7;
  border-radius: 4px;
  font-size: 0.85rem;
}

.formula-label {
  font-weight: 600;
  color: #2d3748;
  margin-right: 0.5rem;
}

.score-formula code {
  background-color: #fff;
  padding: 0.25rem 0.5rem;
  border-radius: 3px;
  font-family: 'Courier New', monospace;
  color: #2d3748;
  font-size: 0.8rem;
}

@media (max-width: 768px) {
  .charts-grid {
    grid-template-columns: 1fr;
  }

  .meta-info {
    flex-direction: column;
    gap: 0.5rem;
  }

  .score-formula {
    font-size: 0.75rem;
  }

  .score-formula code {
    display: block;
    margin-top: 0.5rem;
    word-break: break-all;
  }
}
</style>
