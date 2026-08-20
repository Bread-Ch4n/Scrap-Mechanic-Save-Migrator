<template>
  <button :class="{ active }" class="tab-btn" label="" @click="$emit('click')">
    <span v-if="icon" :style="{ backgroundColor: iconColor }" class="tab-icon" />
    <span class="sm-tab-small tab-label">{{ label }}</span>
  </button>
</template>

<script setup>
defineProps({
  label: { type: String, required: true },
  icon: { type: Boolean, default: false },
  iconColor: { type: String, default: "#d9762b" },
  active: { type: Boolean, default: false }
});
defineEmits(["click"]);
</script>

<style scoped>
.tab-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  background: transparent;
  border: none;
  border-bottom: 2px solid transparent;
  padding: 6px 10px;
  cursor: pointer;
  color: var(--sm-ink-dim);
}

.tab-btn.active {
  color: var(--sm-yellow);
  border-bottom-color: var(--sm-yellow);
}

.tab-icon {
  width: 12px;
  height: 12px;
  border-radius: 2px;
  flex-shrink: 0;
}

.tab-label {
  white-space: nowrap;
}
</style>