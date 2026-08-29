<template>
  <label
    :class="{
      'border-sm-yellow bg-sm-panel': file,
    }"
    class="flex w-full cursor-pointer items-center gap-3.5 rounded-[10px] border border-sm-line bg-sm-bg p-3.5 transition-[border-color,background-color,transform] duration-200 hover:border-sm-yellow hover:bg-sm-panel active:scale-[0.99]"
  >
    <input accept=".db" class="hidden" type="file" @change="handleChange" />

    <div
      class="flex size-[42px] shrink-0 items-center justify-center rounded-lg bg-sm-panel text-sm-yellow"
    >
      <svg
        class="size-[22px]"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        viewBox="0 0 24 24"
      >
        <path
          d="M4 7.5A2.5 2.5 0 0 1 6.5 5h4l2 2H17.5A2.5 2.5 0 0 1 20 9.5v8A2.5 2.5 0 0 1 17.5 20h-11A2.5 2.5 0 0 1 4 17.5v-10Z"
        />
        <path d="M8 12h8M8 15.5h5" />
      </svg>
    </div>

    <div class="flex min-w-0 flex-1 flex-col gap-[3px]">
      <span
        class="overflow-hidden text-ellipsis whitespace-nowrap text-sm font-semibold text-sm-ink"
      >
        {{ file ? file.name : "Select a save file" }}
      </span>

      <span class="text-xs text-sm-ink-dim">
        {{ file ? formatSize(file.size) : "SQLite database (.db)" }}
      </span>
    </div>

    <div
      class="shrink-0 rounded-md bg-sm-yellow px-[11px] py-[7px] text-xs font-bold text-sm-bg"
    >
      {{ file ? "Change" : "Browse" }}
    </div>
  </label>
</template>

<script lang="ts" setup>
import { computed } from "vue";

const props = defineProps<{
  file: File | null;
}>();

const emit = defineEmits<{
  change: [file: File];
}>();

const file = computed(() => props.file);

const handleChange = (event: Event) => {
  const input = event.target as HTMLInputElement;
  const selected = input.files?.[0];

  if (!selected) {
    return;
  }

  emit("change", selected);
};

const formatSize = (bytes: number) => {
  if (bytes < 1024) {
    return `${bytes} B`;
  }

  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  }

  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
};
</script>
