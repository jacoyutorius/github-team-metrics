<template>
  <div class="file-uploader">
    <div class="upload-area" @dragover.prevent @drop.prevent="handleDrop">
      <input
        type="file"
        id="fileInput"
        ref="fileInput"
        accept=".json"
        @change="handleFileSelect"
        style="display: none"
      />
      <label for="fileInput" class="upload-label">
        <div class="upload-content">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="48"
            height="48"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
            <polyline points="17 8 12 3 7 8"></polyline>
            <line x1="12" y1="3" x2="12" y2="15"></line>
          </svg>
          <p class="upload-text">
            クリックしてJSONファイルを選択<br />
            またはドラッグ&ドロップ
          </p>
        </div>
      </label>
    </div>
    <div v-if="error" class="error-message">{{ error }}</div>
    <div v-if="fileName" class="file-info">
      読み込み済み: <strong>{{ fileName }}</strong>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import type { GitHubMetrics } from '../types/metrics'

const emit = defineEmits<{
  (e: 'upload', data: GitHubMetrics): void
}>()

const fileInput = ref<HTMLInputElement>()
const fileName = ref<string>('')
const error = ref<string>('')

const handleFileSelect = (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (file) {
    processFile(file)
  }
}

const handleDrop = (event: DragEvent) => {
  const file = event.dataTransfer?.files[0]
  if (file) {
    processFile(file)
  }
}

const processFile = (file: File) => {
  error.value = ''

  if (!file.name.endsWith('.json')) {
    error.value = 'JSONファイルを選択してください'
    return
  }

  const reader = new FileReader()
  reader.onload = (e) => {
    try {
      const content = e.target?.result as string
      const data = JSON.parse(content) as GitHubMetrics

      // 基本的なバリデーション
      if (!data.summary || !data.repositories || !data.personal_metrics) {
        throw new Error('無効なメトリクスデータ形式です')
      }

      fileName.value = file.name
      emit('upload', data)
    } catch (err) {
      error.value = `JSONの解析に失敗しました: ${err instanceof Error ? err.message : 'Unknown error'}`
    }
  }
  reader.readAsText(file)
}
</script>

<style scoped>
.file-uploader {
  margin-bottom: 2rem;
}

.upload-area {
  border: 2px dashed #cbd5e0;
  border-radius: 8px;
  padding: 2rem;
  text-align: center;
  transition: all 0.3s;
  cursor: pointer;
}

.upload-area:hover {
  border-color: #4299e1;
  background-color: #f7fafc;
}

.upload-label {
  cursor: pointer;
  display: block;
}

.upload-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  color: #4a5568;
}

.upload-text {
  margin: 0;
  font-size: 0.95rem;
  line-height: 1.6;
}

.error-message {
  margin-top: 1rem;
  padding: 0.75rem;
  background-color: #fed7d7;
  color: #c53030;
  border-radius: 4px;
  font-size: 0.9rem;
}

.file-info {
  margin-top: 1rem;
  padding: 0.75rem;
  background-color: #c6f6d5;
  color: #22543d;
  border-radius: 4px;
  font-size: 0.9rem;
}
</style>
