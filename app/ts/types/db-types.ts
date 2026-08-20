interface Game {
  gametick: number;
  mods: Uint8Array;
}

interface GameMode {
  name: string;
  uuid: string;
  mods: string;
  steamID: string;
}

export type { Game, GameMode };
