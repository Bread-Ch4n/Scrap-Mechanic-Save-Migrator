<template>
  <div
    class="bg-sm-panel border border-sm-line rounded-md overflow-hidden font-mono text-sm"
  >
    <div class="px-3 py-2 bg-sm-bg border-b border-sm-line text-sm-ink-dim">
      SQL Logs
    </div>

    <div class="p-3 h-64 overflow-y-auto">
      <div
        v-for="(line, index) in logs"
        :key="index"
        class="whitespace-pre-wrap text-sm-ink"
      >
        <span class="text-sm-yellow">$ </span>{{ line }}
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
defineProps<{
  logs: string[];
}>();
</script>
