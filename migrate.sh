#!/usr/bin/env bash

set -o pipefail

APP_ID="387990"
VDF="$HOME/.steam/steam/steamapps/libraryfolders.vdf"

ESC=$'\033'
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"

RED="${ESC}[31m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
CYAN="${ESC}[36m"
WHITE="${ESC}[97m"
GRAY="${ESC}[90m"

clear

repeat_char() {
    local char="$1"
    local count="$2"

    printf '%*s' "$count" '' | tr ' ' "$char"
}

header() {
    local title="$1"
    local subtitle="$2"

    echo
    printf '%b\n' "${YELLOW}${BOLD}$(repeat_char '=' 72)${RESET}"
    printf '%b\n' "${YELLOW}${BOLD}  ${WHITE}${title}${RESET}"
    printf '%b\n' "${GRAY}  ${subtitle}${RESET}"
    printf '%b\n' "${YELLOW}${BOLD}$(repeat_char '=' 72)${RESET}"
    echo
}

section() {
    echo
    printf '%b\n' "${YELLOW}${BOLD}--- $1 ---${RESET}"
    echo
}

ok() {
    printf '  %b %s\n' "${GREEN}[OK]${RESET}" "$1"
}

fail() {
    printf '  %b %s\n' "${RED}[FAIL]${RESET}" "$1"
}

warn() {
    printf '  %b %s\n' "${YELLOW}[WARN]${RESET}" "$1"
}

step() {
    printf '  %b %s\n' "${CYAN}[..]${RESET}" "$1"
}

detail() {
    printf '      %b\n' "${DIM}$1${RESET}"
}

die() {
    echo
    fail "$1"
    echo
    exit 1
}

confirm() {
    local prompt="$1"
    local answer

    printf '  %b' "${WHITE}${prompt} [y/N]: ${RESET}"
    read -r answer

    [[ "$answer" =~ ^[Yy]$ ]]
}

choose() {
    local prompt="$1"
    local count="$2"
    local choice

    while true; do
        printf '  %b' "${WHITE}${prompt}: ${RESET}"
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
            REPLY="$choice"
            return 0
        fi

        printf '  %b\n' "${RED}[ERROR]${RESET} Enter a number from 1 to $count."
    done
}

get_steam_name() {
    local steam_id="$1"
    local xml

    xml=$(curl \
        --silent \
        --show-error \
        --location \
        --max-time 5 \
        "https://steamcommunity.com/profiles/${steam_id}?xml=1" \
        2>/dev/null) || return 1

    if [[ -z "$xml" ]]; then
        return 1
    fi

    printf '%s\n' "$xml" |
        sed -n 's:.*<steamID><!\[CDATA\[\(.*\)\]\]></steamID>.*:\1:p' |
        head -n 1
}

copy_database() {
    local source="$1"
    local destination="$2"

    cp -- "$source" "$destination"
}

run_migration() {
    local database="$1"

    python3 - "$database" <<'PY'
import sqlite3
import sys

db_path = sys.argv[1]

conn = sqlite3.connect(db_path)

try:
    cursor = conn.cursor()

    cursor.execute("""
        UPDATE Game
        SET flags = 15,
            mods = X'0000000100000000E0E1EF6B5C6453510B28F576470573F9A9361B19'
        WHERE savegameversion = 28
          AND flags = 14
          AND mods = X'00000000';
    """)

    game_rows = cursor.rowcount

    cursor.execute("""
        UPDATE ScriptData
        SET uid = X'B6E35C9767BF5555A519A066E14A8C1E',
            data = X'B6E35C9767BF5555A519A066E14A8C1E' || SUBSTR(data, 17)
        WHERE uid = X'2C3699B2FD9C503EA405CF73434E2E88'
          AND SUBSTR(data, 1, 16) = X'2C3699B2FD9C503EA405CF73434E2E88';
    """)

    scriptdata_rows = cursor.rowcount

    cursor.execute("SELECT id, data FROM Container")
    rows = cursor.fetchall()

    containers_scanned = len(rows)
    containers_updated = 0

    for container_id, data in rows:
        if data is None:
            continue

        hex_data = data.hex()

        if len(hex_data) < 22:
            continue

        try:
            current_size = int(hex_data[14:18], 16)
        except ValueError:
            continue

        if current_size != 40:
            continue

        needed_slots = 60 - current_size

        header = hex_data[:14]
        new_size = "003C"
        stack_size = hex_data[18:22]

        items_length = current_size * 44
        required_length = 22 + items_length

        if required_length > len(hex_data):
            continue

        items = hex_data[22:22 + items_length]

        empty_slot = "00000000000000000000000000000000ffffffff0000"
        padding = empty_slot * needed_slots

        tail_index = 22 + items_length
        tail = hex_data[tail_index:]

        patched_hex = (
            header
            + new_size
            + stack_size
            + items
            + padding
            + tail
        )

        cursor.execute(
            "UPDATE Container SET data = ? WHERE id = ?",
            (bytes.fromhex(patched_hex), container_id)
        )

        containers_updated += 1

    conn.commit()

    print(
        f"{game_rows}|"
        f"{scriptdata_rows}|"
        f"{containers_scanned}|"
        f"{containers_updated}"
    )

except Exception:
    conn.rollback()
    raise

finally:
    conn.close()
PY
}

header \
    "SCRAP MECHANIC SAVE MIGRATOR" \
    "Survival -> Fant Mod 3 Custom Gamemode"

printf '%b\n' "${DIM}Steam App ID: ${APP_ID}${RESET}"
printf '%b\n' "${DIM}Migration engine: SQLite / Python${RESET}"

section "STEAM LIBRARY"

if [[ ! -f "$VDF" ]]; then
    die "Steam library configuration not found:
$VDF"
fi

library_path=$(
    awk '
        /"path"/ {
            path=$2
            gsub(/"/, "", path)
        }
        /"'"$APP_ID"'"/ {
            print path
            exit
        }
    ' "$VDF"
)

[[ -n "$library_path" ]] || die "Steam library containing App ID $APP_ID was not found."

ok "Steam library located"
detail "$library_path"

user_path="$library_path/steamapps/compatdata/$APP_ID/pfx/drive_c/users/steamuser/AppData/Roaming/Axolot Games/Scrap Mechanic/User"

[[ -d "$user_path" ]] || die "Scrap Mechanic User directory not found:
$user_path"

section "SELECT USER"

mapfile -t users < <(
    find "$user_path" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name 'User_*' \
        -printf '%f\n' |
        sort
)

(( ${#users[@]} > 0 )) || die "No Scrap Mechanic user directories found."

declare -a user_ids
declare -a user_names

for user in "${users[@]}"; do
    steam_id="${user#User_}"

    if [[ "$steam_id" =~ ^[0-9]{17}$ ]]; then
        steam_name=$(get_steam_name "$steam_id")

        if [[ -z "$steam_name" ]]; then
            steam_name="Steam account unavailable"
        fi
    else
        steam_id="Unknown"
        steam_name="Invalid Steam user"
    fi

    user_ids+=("$steam_id")
    user_names+=("$steam_name")
done

for i in "${!users[@]}"; do
    printf '  %b %b\n' \
        "${YELLOW}[$((i + 1))]${RESET}" \
        "${WHITE}${user_names[i]}${RESET}"

    printf '      %b\n' \
        "${GRAY}SteamID64: ${user_ids[i]}${RESET}"
done

echo

choose "User" "${#users[@]}"

user_index=$((REPLY - 1))
user_id="${users[user_index]}"
steam_id="${user_ids[user_index]}"
steam_name="${user_names[user_index]}"

ok "User selected"
detail "$steam_name"
detail "SteamID64: $steam_id"

survival_path="$user_path/$user_id/Save/Survival"
custom_path="$user_path/$user_id/Save/Custom"

[[ -d "$survival_path" ]] || die "Survival directory not found:
$survival_path"

mkdir -p "$custom_path" || die "Unable to create Custom directory:
$custom_path"

section "SELECT SURVIVAL DATABASE"

mapfile -t db_files < <(
    find "$survival_path" \
        -maxdepth 1 \
        -type f \
        -iname '*.db' \
        -printf '%f\n' |
        sort
)

(( ${#db_files[@]} > 0 )) || die "No .db files found in the Survival directory."

for i in "${!db_files[@]}"; do
    file="$survival_path/${db_files[i]}"
    size=$(du -h "$file" | cut -f1)

    printf '  %b %b %s\n' \
        "${YELLOW}[$((i + 1))]${RESET}" \
        "${WHITE}${db_files[i]}${RESET}" \
        "${GRAY}(${size})${RESET}"
done

echo

choose "Database" "${#db_files[@]}"
db_name="${db_files[$((REPLY - 1))]}"

source_db="$survival_path/$db_name"

base_name="${db_name%.db}"
output_db="$custom_path/${base_name}_migrated.db"

section "MIGRATION"

printf '  %b\n' "${CYAN}Steam account:${RESET}"
printf '    %s\n' "$steam_name"

printf '    %b\n' "${GRAY}SteamID64: $steam_id${RESET}"

echo

printf '  %b\n' "${CYAN}Source:${RESET}"
printf '    %s\n' "$source_db"

echo

printf '  %b\n' "${CYAN}Destination:${RESET}"
printf '    %s\n' "$output_db"

echo

if [[ -e "$output_db" ]]; then
    warn "Destination already exists."
    detail "$output_db"
    echo

    if ! confirm "Overwrite existing database?"; then
        echo
        step "Migration cancelled."
        echo
        exit 0
    fi

    rm -f -- "$output_db" || die "Unable to remove existing destination."
fi

echo

if ! confirm "Start migration?"; then
    echo
    step "Migration cancelled."
    echo
    exit 0
fi

echo

section "COPYING SAVE"

step "Copying Survival database..."

if ! copy_database "$source_db" "$output_db"; then
    die "Failed to copy database."
fi

ok "Database copied"

section "MIGRATING DATABASE"

step "Applying Game migration..."
step "Applying ScriptData migration..."
step "Expanding player inventories..."

migration_output=$(run_migration "$output_db")
migration_status=$?

if (( migration_status != 0 )); then
    echo
    fail "Database migration failed."
    echo
    warn "Original Survival save was not modified."
    detail "Failed output: $output_db"
    echo
    exit 1
fi

IFS='|' read -r game_rows scriptdata_rows containers_scanned containers_updated <<< "$migration_output"

ok "All migrations completed"

echo
printf '  %-28s %s\n' "Game rows updated" "$game_rows"
printf '  %-28s %s\n' "ScriptData rows updated" "$scriptdata_rows"
printf '  %-28s %s\n' "Containers scanned" "$containers_scanned"
printf '  %-28s %s\n' "Inventories expanded" "$containers_updated"

section "COMPLETE"

printf '%b\n' "${GREEN}${BOLD}  MIGRATION SUCCESSFUL${RESET}"
echo

printf '  %-16s %s\n' "Account" "$steam_name"
printf '  %-16s %s\n' "SteamID64" "$steam_id"
printf '  %-16s %s\n' "Database" "$db_name"

echo
printf '  %-16s %s\n' "Output" "$output_db"

echo
printf '%b\n' "${GREEN}${BOLD}  [OK] Migrated save is ready in the Custom folder.${RESET}"
echo