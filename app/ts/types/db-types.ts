interface Game {
  gametick: number;
  mods: Uint8Array;
  flags: number;
}

interface GameMode {
  name: string;
  uuid: string;
  mods: string;
  steamID: number;
  extra: {
    inventorySize: number | null;
    flags: number | null;
  } | null;
}

export type { Game, GameMode };
