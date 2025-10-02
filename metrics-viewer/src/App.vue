<script setup lang="ts">
import { ref } from 'vue'
import FileUploader from './components/FileUploader.vue'
import MetricsDashboard from './components/MetricsDashboard.vue'
import type { GitHubMetrics } from './types/metrics'

const metricsData = ref<GitHubMetrics | null>(null)

const handleUpload = (data: GitHubMetrics) => {
  metricsData.value = data
}
</script>

<template>
  <div class="app">
    <div class="container">
      <FileUploader @upload="handleUpload" />
      <MetricsDashboard v-if="metricsData" :metrics="metricsData" />
      <div v-else class="placeholder">
        <p>JSONファイルをアップロードしてメトリクスを表示します</p>
      </div>
    </div>
  </div>
</template>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial,
    sans-serif;
  background-color: #f7fafc;
  color: #2d3748;
}

.app {
  min-height: 100vh;
  padding: 2rem 1rem;
}

.container {
  max-width: 1400px;
  margin: 0 auto;
}

.placeholder {
  text-align: center;
  padding: 4rem 2rem;
  color: #a0aec0;
}
</style>
