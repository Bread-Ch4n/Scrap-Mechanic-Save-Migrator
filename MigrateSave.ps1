# =======================================================
#         Scrap Mechanic Fant Migration Tool
#                By Linus and Gemini
# =======================================================

$Host.UI.RawUI.WindowTitle = "Scrap Mechanic Save Migration Tool"

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$sqliteBin = Join-Path $scriptDir "sqlite3.exe"

# Global cache for Steam Display Names to prevent redundant web calls
$global:SteamNameCache = @{}

# Helper function to fetch Steam Persona Name via Raw HTML Regex
function Get-SteamPersonaName ([string]$steamId64) {
    if ($global:SteamNameCache.ContainsKey($steamId64)) {
        return $global:SteamNameCache[$steamId64]
    }

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    try {
        $url = "https://steamcommunity.com/profiles/$steamId64"
        $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
        $response = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        $html = $response.Content

        if ($html -match 'class="actual_persona_name">([^<]+)</span>') {
            $persona = [System.Net.WebUtility]::HtmlDecode($Matches[1].Trim())
            if (-not [string]::IsNullOrWhiteSpace($persona)) {
                $displayName = "$persona (User_$steamId64)"
                $global:SteamNameCache[$steamId64] = $displayName
                return $displayName
            }
        }
    } catch { }

    $fallback = "User_$steamId64"
    $global:SteamNameCache[$steamId64] = $fallback
    return $fallback
}

# 1. Check for bundled sqlite3.exe
if (-not (Test-Path $sqliteBin)) {
    Write-Host "`n[ERROR] 'sqlite3.exe' was not found in this directory!" -ForegroundColor Red
    Write-Host "Please place 'sqlite3.exe' next to this script.`n" -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit
}

# 2. Main Menu Selection Flow
function Show-SaveMenu {
    while ($true) {
        $userDir = "$env:APPDATA\Axolot Games\Scrap Mechanic\User"
        $rawItems = @()

        if (Test-Path $userDir) {
            $rawItems = @(Get-ChildItem -Path "$userDir\User_*\Save" -Filter "*.db" -Recurse -ErrorAction SilentlyContinue |
                          Where-Object { $_.Extension -eq ".db" })
        }

        # Build list of save objects
        $saveObjects = @()
        foreach ($item in $rawItems) {
            $accName = "Unknown Profile"
            if ($item.FullName -match '(?i)\\User_(\d{17})\\') {
                $steamId64 = $Matches[1]
                $accName = Get-SteamPersonaName $steamId64
            } elseif ($item.FullName -match '(?i)\\User_([^\\]+)\\') {
                $accName = "User_$($Matches[1])"
            }

            $saveType = "Other"
            if ($item.FullName -match '(?i)\\Save\\Survival\\') { $saveType = "Survival" }
            elseif ($item.FullName -match '(?i)\\Save\\Custom\\') { $saveType = "Custom" }

            $saveObjects += [PSCustomObject]@{
                Path    = $item.FullName
                Name    = $item.Name
                Account = $accName
                Type    = $saveType
            }
        }

        # STEP 1: USER SELECTION (Forced Array)
        $groupedUsers = @($saveObjects | Group-Object Account)
        $selectedUserGroup = $null

        if ($groupedUsers.Count -eq 0) {
            Write-Host "[!] No save files found in AppData.`n" -ForegroundColor Yellow
            Write-Host "  picking a file will not touch the original file in any way" -ForegroundColor Gray
            Write-Host "  every edit on the selected file will be done on a copy`n" -ForegroundColor Gray
            $rawInput = Read-Host "Drag and drop a .db save file here and press Enter"
            $dragPath = $rawInput.Trim('"').Trim("'")
            if (Test-Path $dragPath) {
                return @{ Path = $dragPath; Mode = "Custom" }
            }
            continue
        } elseif ($groupedUsers.Count -eq 1) {
            # FAILSAFE: Exactly 1 profile exists, automatically skip user selection menu
            $selectedUserGroup = $groupedUsers[0]
        } else {
            Clear-Host
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host "         Scrap Mechanic Fant Migration Tool" -ForegroundColor Cyan
            Write-Host "                By Linus and Gemini" -ForegroundColor DarkCyan
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Found $($groupedUsers.Count) Steam profiles:`n" -ForegroundColor Green

            for ($u = 0; $u -lt $groupedUsers.Count; $u++) {
                $usr = $groupedUsers[$u]
                Write-Host "  [$($u+1)] $($usr.Name) " -NoNewline -ForegroundColor Yellow
                Write-Host "($($usr.Count) total saves)" -ForegroundColor Gray
            }

            Write-Host ""
            Write-Host "  [M] Manual input / Drag & Drop a .db file`n" -ForegroundColor White
            Write-Host "  picking a file will not touch the original file in any way" -ForegroundColor Gray
            Write-Host "  every edit on the selected file will be done on a copy`n" -ForegroundColor Gray

            $userChoice = Read-Host "Select a user profile number (1-$($groupedUsers.Count)) or 'M'"

            if ($userChoice -eq 'M' -or $userChoice -eq 'm') {
                $rawInput = Read-Host "`nDrag and drop your .db save file here and press Enter"
                $dragPath = $rawInput.Trim('"').Trim("'")
                if (Test-Path $dragPath) { return @{ Path = $dragPath; Mode = "Custom" } }
                continue
            }

            if ($userChoice -match '^\d+$') {
                $uIdx = [int]$userChoice - 1
                if ($uIdx -ge 0 -and $uIdx -lt $groupedUsers.Count) {
                    $selectedUserGroup = $groupedUsers[$uIdx]
                }
            }

            if (-not $selectedUserGroup) { continue }
        }

        # STEP 2: MODE SELECTION (Vanilla Survival vs Custom Game)
        while ($true) {
            Clear-Host
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host "         Scrap Mechanic Fant Migration Tool" -ForegroundColor Cyan
            Write-Host "                By Linus and Gemini" -ForegroundColor DarkCyan
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Selected Profile: $($selectedUserGroup.Name)" -ForegroundColor Green
            Write-Host ""

            $survCount = @($selectedUserGroup.Group | Where-Object { $_.Type -eq "Survival" }).Count
            $custCount = @($selectedUserGroup.Group | Where-Object { $_.Type -eq "Custom" }).Count

            Write-Host "Select Conversion Mode:" -ForegroundColor White
            Write-Host "  [1] Convert Vanilla Survival Save -> Fant Mod (from \Save\Survival\) " -NoNewline -ForegroundColor Yellow
            Write-Host "($survCount save(s))" -ForegroundColor Gray

            Write-Host "  [2] Convert Existing Custom Game Save -> Fant Mod (from \Save\Custom\) " -NoNewline -ForegroundColor Yellow
            Write-Host "($custCount save(s))" -ForegroundColor Gray
            Write-Host "      * Intended for converting smaller, Vanilla+ / QoL Custom Games to Fant Mod 3" -ForegroundColor DarkGray
			Write-Host "        (meaning no custom games that add new things, only tweaks to stuff)" -ForegroundColor DarkGray

            Write-Host ""
            if ($groupedUsers.Count -gt 1) {
                Write-Host "  [B] Back to user selection" -ForegroundColor Cyan
            }
            Write-Host "  [M] Manual input / Drag & Drop a .db file`n" -ForegroundColor White
            Write-Host "  picking a file will not touch the original file in any way" -ForegroundColor Gray
            Write-Host "  every edit on the selected file will be done on a copy`n" -ForegroundColor Gray

            $modeChoice = Read-Host "Select mode (1 or 2)"

            if ($groupedUsers.Count -gt 1 -and ($modeChoice -eq 'B' -or $modeChoice -eq 'b')) {
                break
            }

            if ($modeChoice -eq 'M' -or $modeChoice -eq 'm') {
                $rawInput = Read-Host "`nDrag and drop your .db save file here and press Enter"
                $dragPath = $rawInput.Trim('"').Trim("'")
                if (Test-Path $dragPath) { return @{ Path = $dragPath; Mode = "Custom" } }
                continue
            }

            $selectedMode = $null
            if ($modeChoice -eq '1') { $selectedMode = "Survival" }
            elseif ($modeChoice -eq '2') { $selectedMode = "Custom" }

            if (-not $selectedMode) { continue }

            # Filter saves for this mode (Forced Array)
            $filteredSaves = @($selectedUserGroup.Group | Where-Object { $_.Type -eq $selectedMode })

            # STEP 3: SAVE FILE SELECTION
            while ($true) {
                Clear-Host
                Write-Host "=======================================================" -ForegroundColor Cyan
                Write-Host "         Scrap Mechanic Fant Migration Tool" -ForegroundColor Cyan
                Write-Host "                By Linus and Gemini" -ForegroundColor DarkCyan
                Write-Host "=======================================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Profile: $($selectedUserGroup.Name) | Mode: $selectedMode Save" -ForegroundColor Green

                if ($filteredSaves.Count -eq 0) {
                    Write-Host "`n[!] No $selectedMode save files found for this profile.`n" -ForegroundColor Yellow
                    Read-Host "Press Enter to go back..."
                    break
                }

                Write-Host "Found $($filteredSaves.Count) save file(s):`n" -ForegroundColor Gray
                for ($s = 0; $s -lt $filteredSaves.Count; $s++) {
                    Write-Host "  [$($s+1)] $($filteredSaves[$s].Name)" -ForegroundColor Yellow
                }

                Write-Host "`n  [B] Back to conversion mode selection" -ForegroundColor Cyan
                Write-Host "  [M] Manual input / Drag & Drop a .db file`n" -ForegroundColor White
				Write-Host ""
                Write-Host "  picking a file will not touch the original file in any way" -ForegroundColor Gray
                Write-Host "  every edit on the selected file will be done on a copy`n" -ForegroundColor Gray

                $saveChoice = Read-Host "Select a save file number (1-$($filteredSaves.Count))"

                if ($saveChoice -eq 'B' -or $saveChoice -eq 'b') {
                    break
                }

                if ($saveChoice -eq 'M' -or $saveChoice -eq 'm') {
                    $rawInput = Read-Host "`nDrag and drop your .db save file here and press Enter"
                    $dragPath = $rawInput.Trim('"').Trim("'")
                    if (Test-Path $dragPath) { return @{ Path = $dragPath; Mode = $selectedMode } }
                    continue
                }

                if ($saveChoice -match '^\d+$') {
                    $sIdx = [int]$saveChoice - 1
                    if ($sIdx -ge 0 -and $sIdx -lt $filteredSaves.Count) {
                        return @{ Path = $filteredSaves[$sIdx].Path; Mode = $selectedMode }
                    }
                }
            }
        }
    }
}

$selection = Show-SaveMenu
$sourceSave = $selection.Path
$conversionMode = $selection.Mode

Write-Host "`nSource Save: `"$sourceSave`"" -ForegroundColor Cyan

# 3. Setup Temporary Working Directory in Script CD
Write-Host "`n[1/3] Copying save to local temp working directory..." -ForegroundColor Gray

$tempWorkDir = Join-Path $scriptDir "temp_migrate"
if (Test-Path $tempWorkDir) { Remove-Item $tempWorkDir -Recurse -Force | Out-Null }
New-Item -ItemType Directory -Path $tempWorkDir -Force | Out-Null

$tempSaveFile = Join-Path $tempWorkDir "working_save.db"
Copy-Item -Path $sourceSave -Destination $tempSaveFile -Force
Write-Host "   Working copy created at: `"$tempSaveFile`"" -ForegroundColor DarkGray

# 4. Execute Flag-Based SQL Migration on Temp File
Write-Host "`n[2/3] Executing SQL Database Migration..." -ForegroundColor Gray

# Step A: Update ScriptData GUID to Fant Mod 3
$tempSql = Join-Path $env:TEMP "sm_migrate_temp.sql"
$sqlQueries = @"
UPDATE ScriptData SET uid = X'B6E35C9767BF5555A519A066E14A8C1E' WHERE uid = X'2C3699B2FD9C503EA405CF73434E2E88';
UPDATE ScriptData SET data = X'B6E35C9767BF5555A519A066E14A8C1E' || SUBSTR(data, 17) WHERE uid = X'B6E35C9767BF5555A519A066E14A8C1E' AND SUBSTR(data, 1, 16) = X'2C3699B2FD9C503EA405CF73434E2E88';
"@
Set-Content -Path $tempSql -Value $sqlQueries -Encoding UTF8
Get-Content $tempSql | & $sqliteBin "$tempSaveFile"
if (Test-Path $tempSql) { Remove-Item $tempSql }

# Step B: Check original Game.flags before setting flag 15
# Exact 24-byte (48 hex char) UGC Item for Fant Mod 3
$fantUgcItemHex = "00000000E0E1EF6B5C6453510B28F576470573F9A9361B19" 

try {
    $gameRow = & $sqliteBin "$tempSaveFile" "SELECT flags, hex(mods) FROM Game LIMIT 1;"
    if ($gameRow -and $gameRow -match '^\s*(\d+)\|(.*)$') {
        $origFlags = [int]$Matches[1]
        $existingModsHex = $Matches[2].Trim()

        if ([string]::IsNullOrWhiteSpace($existingModsHex) -or $existingModsHex -eq "00000000" -or $existingModsHex.Length -lt 8) {
            # Empty / No mods -> Standard 1-Mod Array
            $newModsHex = "00000001" + $fantUgcItemHex
        } else {
            $countHex = $existingModsHex.Substring(0, 8)
            $payload  = $existingModsHex.Substring(8)
            $modCount = [System.Convert]::ToUInt32($countHex, 16)

            if ($origFlags -eq 15 -and $payload.Length -ge 48) {
                # WAS A CUSTOM GAME SAVE (flags = 15): Overwrite Slot 0 (old Custom Game Mode)
                $secondaryModsHex = $payload.Substring(48)
                $newModsHex = $countHex + $fantUgcItemHex + $secondaryModsHex
                Write-Host "   Custom Game save detected (flags=15): Replaced primary game mode UUID." -ForegroundColor Green
            } else {
                # WAS A SURVIVAL SAVE (flags = 14): Prepend Fant Mod so NO B&P mods are lost
                if ($payload -notlike "*$fantUgcItemHex*") {
                    $newCountHex = ($modCount + 1).ToString("X8")
                    $newModsHex  = $newCountHex + $fantUgcItemHex + $payload
                    Write-Host "   Survival save detected (flags=14): Prepend Fant Mod (+1 count, preserved all $modCount B&P mods)." -ForegroundColor Green
                } else {
                    $newModsHex = $existingModsHex
                }
            }
        }

        # Set flags = 15 and write updated mod payload
        & $sqliteBin "$tempSaveFile" "UPDATE Game SET flags = 15, savegameversion = 28, mods = x'$newModsHex';"
    }
} catch {
    Write-Host "   [!] Failed to parse Game table. Applied default Fant Mod linkage." -ForegroundColor Yellow
    & $sqliteBin "$tempSaveFile" "UPDATE Game SET flags = 15, savegameversion = 28, mods = x'00000001$fantUgcItemHex';"
}

# 5. Scan and Rebuild Container BLOBs on Temp File
Write-Host "`n[3/3] Scanning and Rebuilding Player Inventory Containers..." -ForegroundColor Gray

try {
    $rows = @(& $sqliteBin "$tempSaveFile" "SELECT id, hex(data) FROM Container;")
} catch {
    Write-Host "[ERROR] Failed to query Container table: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit
}

if (-not $rows) {
    Write-Host "   [!] Container table is empty." -ForegroundColor Yellow
} else {
    $rowCount = $rows.Count
    Write-Host "   Total containers scanned: $rowCount" -ForegroundColor Cyan
    $updatedCount = 0

    foreach ($row in $rows) {
        if ([string]::IsNullOrWhiteSpace($row)) { continue }
        $parts = $row.Split('|')
        if ($parts.Count -lt 2) { continue }

        $id = $parts[0]
        $hex = $parts[1]

        if ($hex.Length -lt 22) { continue }

        $sizeHex = $hex.Substring(14, 4)
        try {
            $currentSize = [System.Convert]::ToUInt16($sizeHex, 16)
        } catch {
            continue
        }

        if ($currentSize -eq 40) {
            Write-Host "   [MATCH] Player Inventory ID $id detected (40 slots) -> Expanding to 60 slots..." -ForegroundColor Yellow
            
            $neededSlots = 60 - $currentSize
            $header = $hex.Substring(0, 14)
            $newSizeHex = "003C"
            $stackSize = $hex.Substring(18, 4)
            $itemsLen = $currentSize * 44
            $requiredLen = 22 + $itemsLen

            if ($requiredLen -gt $hex.Length) { continue }

            $items = $hex.Substring(22, $itemsLen)
            $emptySlot = "00000000000000000000000000000000ffffffff0000"
            $padding = $emptySlot * $neededSlots
            $tailIndex = 22 + $itemsLen
            $tail = $hex.Substring($tailIndex)

            $patchedHex = $header + $newSizeHex + $stackSize + $items + $padding + $tail
            $updateSql = "UPDATE Container SET data = x'$patchedHex' WHERE id = $id;"

            & $sqliteBin "$tempSaveFile" "$updateSql"
            Write-Host "      [+] SUCCESS: Expanded Container ID $id to 60 slots!" -ForegroundColor Green
            $updatedCount++
        }
    }
    Write-Host "`n   Operation Complete. Total player inventories expanded: $updatedCount" -ForegroundColor Cyan
}

# 6. Output Target Placement
if ($conversionMode -eq "Custom") {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($sourceSave)
    $targetDir = Split-Path $sourceSave
    $targetSave = Join-Path $targetDir "$baseName - fant mod.db"
} else {
    $targetSave = [regex]::Replace($sourceSave, '(?i)\\Save\\Survival\\', '\Save\Custom\')
    $targetDir = Split-Path $targetSave
}

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

Copy-Item -Path $tempSaveFile -Destination $targetSave -Force
Remove-Item $tempWorkDir -Recurse -Force | Out-Null

# 7. Final Status
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  SUCCESS! Save migrated and placed in Custom Game menu." -ForegroundColor Green
Write-Host "  Credits to `"taswin`" on the fant mod discord for" -ForegroundColor Green
Write-Host "  finding a reliable method on converting a save and" -ForegroundColor Green
Write-Host "  gemini for helping in 99% of the coding for this tool" -ForegroundColor Green
Write-Host "  Path: `"$targetSave`"" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green

Write-Host ""
Read-Host "Press Enter to exit..."