const formatTicks = (ticks: number) => {
  let seconds = Math.floor(ticks / 40);

  const days = Math.floor(seconds / 86400);
  seconds %= 86400;

  const hours = Math.floor(seconds / 3600);
  seconds %= 3600;

  const minutes = Math.floor(seconds / 60);
  seconds %= 60;

  return { days: days, hours: hours, minutes: minutes, seconds: seconds };
};

const parseMods = (data: Uint8Array) => {
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);

  const count = view.getInt32(0, false);

  const mods = [];

  for (let i = 0; i < count; i++) {
    const offset = 4 + i * 24;

    const fileId = view.getBigUint64(offset, false);

    const uuidBytes = Array.from(data.slice(offset + 8, offset + 24)).reverse();

    const uuid = uuidBytes
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("")
      .replace(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/, "$1-$2-$3-$4-$5");

    mods.push({
      fileId,
      uuid,
    });
  }

  return mods;
};

export { formatTicks, parseMods };
