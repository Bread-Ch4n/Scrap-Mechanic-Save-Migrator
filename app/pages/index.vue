<template>
  <div class="min-h-screen flex items-center justify-center p-6">
    <div class="card">
      <div class="header">Scrap Mechanic Save Migrator</div>

      <Stepper
        :can-proceed="
          (step) => {
            if (step === 1) return !!game;
            if (step === 3) return !!selectedGamemode;
            return true;
          }
        "
        :completed-steps="migrated ? [5] : []"
        :initial-step="1"
        :next-button-props="{
          class: 'hover:brightness-90',
        }"
        back-button-text="Previous"
        check-color="#000"
        complete-button-text="Finish"
        dot-color="#000"
        indicator-active-color="var(--color-sm-yellow)"
        indicator-active-text-color="#000"
        indicator-complete-color="var(--color-sm-yellow)"
        indicator-complete-text-color="#000"
        indicator-inactive-color="var(--color-sm-line)"
        indicator-inactive-text-color="var(--color-sm-yellow)"
        line-background-color="var(--color-sm-line)"
        line-complete-color="var(--color-sm-yellow)"
        next-button-color="var(--color-sm-yellow)"
        next-button-text="Next"
        next-button-text-color="#000"
        @step-change="handleStepChange"
        @final-step-completed="handleFinalStepCompleted"
      >
        <div class="step-content gap-2 flex flex-col">
          <h2 class="sm-header-large-medium text-white">Select your save</h2>

          <FileInput :file="selectedFile" @change="handleFile" />
        </div>

        <div class="step-content">
          <h2 class="sm-header-large-medium text-white">Save Info</h2>

          <div v-if="game" class="game-info">
            <h1 v-if="savename" class="sm-header-xlarge">
              Save Name: {{ savename }}
            </h1>

            <div v-if="gamemode">
              <h1 class="sm-header-xlarge">
                Gamemode:
                <a
                  :href="`https://steamcommunity.com/workshop/filedetails/?id=${gamemode.steamID}`"
                  class="text-sm-yellow"
                  rel="noopener noreferrer"
                  target="_blank"
                >
                  {{ gamemode.name }}
                </a>
              </h1>
            </div>

            <div>
              Game time:
              <span class="sm-number-font">
                {{ formatTicks(game.gametick).days }} </span
              >d
              <span class="sm-number-font">
                {{ formatTicks(game.gametick).hours }} </span
              >h
              <span class="sm-number-font">
                {{ formatTicks(game.gametick).minutes }} </span
              >m
              <span class="sm-number-font">
                {{ formatTicks(game.gametick).seconds }} </span
              >s
            </div>
          </div>
        </div>

        <div v-if="gamemode" class="flex items-center justify-center gap-2">
          <h1 class="sm-header-xlarge shrink-0">
            <a
              :href="`https://steamcommunity.com/workshop/filedetails/?id=${gamemode.steamID}`"
              class="text-sm-yellow underline"
              rel="noopener noreferrer"
              target="_blank"
            >
              {{ gamemode.name }}
            </a>
          </h1>

          <span
            class="flex size-6 shrink-0 items-center justify-center text-sm-yellow"
          >
            <MoveRight class="size-5" />
          </span>

          <USelectMenu
            v-model="selectedGamemode"
            :items="availableGamemodeNames"
            :ui="{
              base: '',
              value: 'sm-header-xlarge text-sm-yellow underline',
              placeholder: 'sm-header-xlarge text-sm-yellow',

              trailing: 'static flex items-center ms-2 p-0',
              trailingIcon: 'text-sm-yellow size-5',

              content: 'bg-sm-panel text-sm-yellow ring-1 ring-sm-yellow',
              viewport: 'bg-sm-panel text-sm-yellow p-1',

              input: '[&_input::placeholder]:text-sm-yellow border-sm-yellow',

              item: [
                'bg-transparent',
                'text-sm-yellow',
                'rounded',
                'before:!bg-transparent',
                'data-highlighted:before:!bg-sm-yellow/10',
              ],

              itemLabel: 'text-sm-yellow',
              itemTrailing: 'ms-auto',
              itemTrailingIcon: 'text-sm-yellow',

              separator: 'border-sm-yellow',
              itemWrapper: 'h',
            }"
            class="select-gamemode"
            placeholder="Select a gamemode"
            size="xl"
            trailing-icon="i-lucide-arrow-down"
            variant="none"
          />
        </div>

        <div class="step-content gap-4 flex flex-col items-center">
          <Terminal :logs="logs" class="w-full" />

          <div class="flex items-center gap-2">
            <button
              class="flex justify-center items-center px-4 py-2 rounded font-medium tracking-tight transition-all duration-300 cursor-pointer bg-sm-yellow text-sm-panel hover:brightness-90"
              type="button"
              @click="migrate"
            >
              Migrate
            </button>

            <button
              v-if="migrated"
              class="flex justify-center items-center px-4 py-2 rounded font-medium tracking-tight transition-all duration-300 cursor-pointer bg-sm-yellow text-sm-panel hover:brightness-90"
              type="button"
              @click="downloadMigratedSave"
            >
              Download
            </button>
          </div>
        </div>
      </Stepper>
    </div>
  </div>
</template>

<script lang="ts" setup>
import type { Game, GameMode } from "~/ts/types/db-types";
import { formatTicks, parseMods } from "~/ts/helpers";
import wasmUrl from "sql.js/dist/sql-wasm.wasm?url";
import FileInput from "~/components/FileInput.vue";
import Terminal from "~/components/Terminal.vue";
import Stepper from "~/components/Stepper.vue";
import { MoveRight } from "@lucide/vue";
import type { Database } from "sql.js";
import { computed, ref } from "vue";
import initSqlJs from "sql.js";

const logs = ref<string[]>([]);
const db = ref<Database | null>(null);
const migrated = ref(false);

const log = (...values: unknown[]) => {
  logs.value.push(
    values
      .map((value) =>
        typeof value === "string" ? value : JSON.stringify(value, null, 2),
      )
      .join(" "),
  );
};

const migrate = () => {
  if (!db.value) {
    log("No database loaded.");
    return;
  }

  if (!gamemode.value) {
    log("No current gamemode found.");
    return;
  }

  if (!selectedGamemodeData.value) {
    log("No target gamemode selected.");
    return;
  }

  const target = selectedGamemodeData.value;
  const current = gamemode.value;

  try {
    migrated.value = false;

    log("Starting migration...");
    log(`Current gamemode: ${current.name}`);
    log(`Target gamemode: ${target.name}`);

    db.value.run(`
      UPDATE Game
      SET flags = 15,
          mods = X'${target.mods}'
      WHERE savegameversion = 28;
    `);

    const gameRows = db.value.getRowsModified();

    log(`Game: ${gameRows} row${gameRows === 1 ? "" : "s"} affected.`);

    db.value.run(`
      UPDATE ScriptData
      SET uid = X'${target.uuid}',
          data = X'${target.uuid}' || SUBSTR(CAST(data AS BLOB), 17)
      WHERE uid = X'${current.uuid}'
        AND SUBSTR(CAST(data AS BLOB), 1, 16) = X'${current.uuid}';
    `);

    const scriptDataRows = db.value.getRowsModified();

    log(
      `ScriptData: ${scriptDataRows} row${
        scriptDataRows === 1 ? "" : "s"
      } affected.`,
    );

    migrated.value = true;

    log("Migration completed successfully.");
  } catch (error) {
    migrated.value = false;
    log("Migration failed:", error);
  }
};

const downloadMigratedSave = () => {
  if (!db.value) {
    log("No database loaded.");
    return;
  }

  if (!migrated.value) {
    log("Database has not been migrated.");
    return;
  }

  const data = db.value.export();

  const blob = new Blob([data], {
    type: "application/x-sqlite3",
  });

  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");

  const originalName = savename.value ?? "save";

  const filename = originalName.endsWith("_migrated")
    ? `${originalName}.db`
    : `${originalName}_migrated.db`;

  link.href = url;
  link.download = filename;

  document.body.appendChild(link);
  link.click();
  link.remove();

  URL.revokeObjectURL(url);

  log(`Downloaded ${filename}.`);
};

const response = await fetch(
  "https://raw.githubusercontent.com/Bread-Ch4n/Scrap-Mechanic-Save-Migrator/refs/heads/info/CustomModes.json",
);

const GamemodeData: GameMode[] = await response.json();

const game = ref<Game | null>(null);
const savename = ref<string | null>(null);
const gamemode = ref<GameMode | null>(null);
const gamemodeData = ref<GameMode[]>(GamemodeData);
const selectedGamemode = ref<string | undefined>(undefined);
const selectedFile = ref<File | null>(null);

const availableGamemodes = computed(() => {
  return gamemodeData.value.filter(
    (gamemodeOption) =>
      gamemodeOption.steamID &&
      gamemodeOption.steamID !== gamemode.value?.steamID,
  );
});

const availableGamemodeNames = computed(() => {
  return availableGamemodes.value.map((gamemodeOption) => gamemodeOption.name);
});

const selectedGamemodeData = computed(() => {
  if (!selectedGamemode.value) {
    return null;
  }

  return (
    availableGamemodes.value.find(
      (gamemodeOption) => gamemodeOption.name === selectedGamemode.value,
    ) ?? null
  );
});

const handleFile = async (file: File) => {
  selectedFile.value = file;

  const SQL = await initSqlJs({
    locateFile: () => wasmUrl,
  });

  savename.value = file.name.replace(/\.db$/i, "");

  const buffer = await file.arrayBuffer();

  db.value = new SQL.Database(new Uint8Array(buffer));

  game.value = null;
  gamemode.value = null;
  selectedGamemode.value = undefined;
  migrated.value = false;
  logs.value = [];

  const gameResult = db.value.exec(`
    SELECT *
    FROM Game
    LIMIT 1
  `)[0];

  if (gameResult?.values[0]) {
    game.value = Object.fromEntries(
      gameResult.columns.map((column, index) => [
        column,
        gameResult.values[0][index],
      ]),
    ) as unknown as Game;
  }

  const mods = parseMods(game.value?.mods);

  gamemode.value =
    GamemodeData.find((gamemode) =>
      mods.some((mod) => gamemode.steamID === mod.fileId.toString()),
    ) ?? null;

  log(`Loaded save: ${file.name}`);

  if (game.value) {
    log("Game data loaded.");
  } else {
    log("Could not find Game data.");
  }

  if (gamemode.value) {
    log(`Detected gamemode: ${gamemode.value.name}`);
  } else {
    log("Could not detect gamemode.");
  }
};

const handleStepChange = (step: number) => {
  migrated.value = false;
  if (step === 5) {
    logs.value = [];
  }
};

const handleFinalStepCompleted = () => {
  console.log("Save gamemode:", gamemode.value);
  console.log("Selected gamemode:", selectedGamemodeData.value);
};
</script>
