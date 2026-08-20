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
      <footer
        class="flex flex-col items-center justify-center text-sm-yellow gap-1 pb-1"
      >
        <p class="m-0">
          OS native versions available in the GitHub
          <a
            class="underline"
            href="https://github.com/Bread-Ch4n/Scrap-Mechanic-Save-Migrator"
            rel="noopener noreferrer"
            target="_blank"
            ><strong>README</strong></a
          >
        </p>
        <p class="m-0">
          Made by
          <a
            class="underline"
            href="https://github.com/Bread-Ch4n"
            rel="noopener noreferrer"
            target="_blank"
            ><strong>Bread-Chan</strong></a
          >
          with ❤︎ · Credits to
          <a
            class="underline"
            href="https://discord.com/users/136620038516899840"
            rel="noopener noreferrer"
            target="_blank"
            ><strong>taswin</strong></a
          >
          for finding the migration process
        </p>
      </footer>
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
import LZ4 from "lz4js";

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
      SET flags = ${target.extra?.flags ?? 15},
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
      `ScriptData: ${scriptDataRows} row${scriptDataRows === 1 ? "" : "s"} affected.`,
    );

    const targetInvSize = target.extra?.inventorySize ?? 40;
    const { scanned, updated } = migratePlayerInventories(
      db.value,
      targetInvSize,
      log,
    );
    log(
      `Inventory: ${scanned} player container(s) checked, ${updated} resized.`,
    );

    migrated.value = true;
    log("Migration completed successfully.");
  } catch (error) {
    migrated.value = false;
    log("Migration failed:", error);
  }
};

const decompressPlayerData = (compressed: Uint8Array): Uint8Array => {
  const output = new Uint8Array(128);
  const size = LZ4.decompressBlock(compressed, output, 0, compressed.length, 0);
  return output.slice(0, size);
};

const getPlayerContainerIds = (db: any) => {
  const result = db.exec(
    "SELECT data FROM GenericData WHERE worldId = 65534 AND flags = 3 ORDER BY key ASC;",
  );
  if (!result.length) return [];

  const entries = [];
  for (const row of result[0].values) {
    const raw = row[0] as unknown as Uint8Array;
    if (!raw || raw.length < 0x1d) continue;

    const compressedSize = raw[0x1c];
    const compressed = raw.slice(0x1d, 0x1d + compressedSize);
    const data = decompressPlayerData(compressed);
    if (data.length < 0x42) continue;

    const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
    const steamId64 = view.getBigUint64(0x2e, false);
    const inventoryContainerId = view.getUint32(0x36, false);
    const carryContainerId = view.getUint32(0x3a, false);

    entries.push({ steamId64, inventoryContainerId, carryContainerId });
  }
  return entries;
};

const resizeContainerById = (db: any, id: any, targetSize: any, log: any) => {
  const result = db.exec(`SELECT hex(data) FROM Container WHERE id = ${id};`);
  if (!result.length || !result[0].values.length) {
    log(`  Container ${id}: not found.`);
    return false;
  }

  const hex = String(result[0].values[0][0]);
  if (hex.length < 22) {
    log(`  Container ${id}: data too short.`);
    return false;
  }

  const currentSize = parseInt(hex.substring(14, 18), 16);
  log(`  Container ${id}: current size ${currentSize}, target ${targetSize}.`);

  if (!Number.isFinite(currentSize) || currentSize === targetSize) return false;

  const header = hex.substring(0, 14);
  const newSizeHex = targetSize.toString(16).padStart(4, "0");
  const stackSize = hex.substring(18, 22);
  const itemsLen = currentSize * 44;
  const requiredLen = 22 + itemsLen;
  if (requiredLen > hex.length) {
    log(`  Container ${id}: data length mismatch, skipping.`);
    return false;
  }

  const items = hex.substring(22, 22 + itemsLen);
  const tail = hex.substring(22 + itemsLen);

  const newItems =
    targetSize > currentSize
      ? items +
        "00000000000000000000000000000000ffffffff0000".repeat(
          targetSize - currentSize,
        )
      : items.substring(0, targetSize * 44);

  const patchedHex = header + newSizeHex + stackSize + newItems + tail;
  db.run(`UPDATE Container SET data = X'${patchedHex}' WHERE id = ${id};`);
  return true;
};

const migratePlayerInventories = (db: any, targetSize: any, log: any) => {
  const players = getPlayerContainerIds(db);
  let updated = 0;

  for (const player of players) {
    log(`Player: ${player.steamId64.toString()}`);

    if (resizeContainerById(db, player.inventoryContainerId, targetSize, log))
      updated++;

    if (player.carryContainerId !== 0xffffffff) {
      if (resizeContainerById(db, player.carryContainerId, targetSize, log))
        updated++;
    }
  }

  return { scanned: players.length, updated };
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

  const data: any = db.value.export();

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

  const gameResult: any = db.value.exec(`
    SELECT *
    FROM Game
    LIMIT 1
  `)[0];

  if (gameResult?.values[0]) {
    game.value = Object.fromEntries(
      gameResult.columns.map((column: any, index: string | number) => [
        column,
        gameResult.values[0][index],
      ]),
    ) as unknown as Game;
  }

  const mods = parseMods(game.value?.mods ?? new Uint8Array());

  gamemode.value =
    GamemodeData.find((gamemode) =>
      mods.some((mod) => gamemode.steamID.toString() === mod.fileId.toString()),
    ) ?? null;

  if (
    gamemode.value == null &&
    mods.length === 0 &&
    game.value &&
    game.value.flags == 14
  ) {
    gamemode.value =
      GamemodeData.find((gamemode) => gamemode.steamID === -1) ?? null;
  }

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
