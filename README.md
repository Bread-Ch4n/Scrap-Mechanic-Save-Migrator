# Scrap Mechanic Save Migrator

Migrate **Scrap Mechanic Survival Saves** into **Fant Mod 3 Custom Gamemode Saves**.

The SQL editing technique behind this tool was found by [taswin](https://discord.com/users/136620038516899840).

## Table of Contents

- [Web Version](#-web-version)
- [Experimental Web Version](#-experimental-web-version)
- [Windows Version](#-windows-version)
- [Linux Version](#-linux-version)

---

## 🌐 Web Version

**[Open the Web Version](https://bread-ch4n.github.io/Scrap-Mechanic-Save-Migrator/)**

No installation required.

**Requirements:** None

---

## 🧪 Experimental Web Version

**[Open the Experimental Web Version](https://bread-ch4n.github.io/Scrap-Mechanic-Save-Migrator/experimental/)**

No installation required. Supports converting Vanilla saves into several Custom Gamemodes, as well as converting between different Custom Gamemodes.

**Requirements:** None

---

## 🪟 Windows Version

**Requirements:** PowerShell

### Usage

1. Open the [Windows Version](https://github.com/Bread-Ch4n/Scrap-Mechanic-Save-Migrator/tree/windows) branch.
2. Click **Code** → **Download ZIP**, or download it directly [here](https://github.com/Bread-Ch4n/Scrap-Mechanic-Save-Migrator/archive/refs/heads/windows.zip).
3. Extract the ZIP file.
4. Run `migrate.bat`.
5. Follow the on-screen instructions.

Windows version by **[Linus (bicheslovesticks)](https://discord.com/users/278861825477574656)** from the Fant Mod Discord server.

---

## 🐧 Linux Version

**Requirements:** `bash`, `python3`, `curl`

### Option 1 — Download the repository

1. Open the [Linux Version](https://github.com/Bread-Ch4n/Scrap-Mechanic-Save-Migrator/tree/linux) branch.
2. Click **Code** → **Download ZIP**, or download it directly [here](https://github.com/Bread-Ch4n/Scrap-Mechanic-Save-Migrator/archive/refs/heads/linux.zip).
3. Extract the ZIP file.
4. Open a terminal in the extracted folder and run:

   ```bash
   bash migrate.sh
   ```

5. Follow the on-screen instructions.

### Option 2 — Run directly (no download)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Bread-Ch4n/Scrap-Mechanic-Save-Migrator/linux/migrate.sh)
```

Follow the on-screen instructions.
