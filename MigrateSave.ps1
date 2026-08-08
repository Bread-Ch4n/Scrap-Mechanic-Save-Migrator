# =======================================================
#         Scrap Mechanic Fant Migration Tool
#                By Linus and Gemini
# =======================================================

$Host.UI.RawUI.WindowTitle = "Scrap Mechanic Save Migration Tool"

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$sqliteBin = Join-Path $scriptDir "sqlite3.exe"

# Global cache for Steam Display Names
$global:SteamNameCache = @{}

# Load local Steam profile names from Steam's local loginusers.vdf file
function Load-LocalSteamProfiles {
    try {
        $steamReg = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue
        if ($steamReg -and $steamReg.SteamPath) {
            $vdfPath = Join-Path $steamReg.SteamPath "config\loginusers.vdf"
            if (Test-Path $vdfPath) {
                $vdfContent = Get-Content -Path $vdfPath -Raw -ErrorAction SilentlyContinue
                $matches = [regex]::Matches($vdfContent, '"(\d{17})"\s*\{[\s\S]*?"PersonaName"\s*"([^"]+)"')
                foreach ($m in $matches) {
                    $id = $m.Groups[1].Value
                    $name = $m.Groups[2].Value
                    $global:SteamNameCache[$id] = "$name (User_$id)"
                }
            }
        }
    } catch { }
}

# Pre-populate local profile names on script start
Load-LocalSteamProfiles

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

        # Match 1: Extract from <span class="actual_persona_name">...</span>
        if ($html -match 'class="actual_persona_name">([^<]+)</span>') {
            $persona = [System.Net.WebUtility]::HtmlDecode($Matches[1].Trim())
            if (-not [string]::IsNullOrWhiteSpace($persona)) {
                $displayName = "$persona (User_$steamId64)"
                $global:SteamNameCache[$steamId64] = $displayName
                return $displayName
            }
        }

        # Match 2: Extract from <title>Steam Community :: Name</title>
        if ($html -match '<title>Steam Community :: ([^<]+)</title>') {
            $persona = [System.Net.WebUtility]::HtmlDecode($Matches[1].Trim())
            if (-not [string]::IsNullOrWhiteSpace($persona) -and $persona -ne "Error") {
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

# 2. Main Menu Loop (2-Step Selection with Single-User Failsafe)
function Show-SaveMenu {
    while ($true) {
        $userDir = "$env:APPDATA\Axolot Games\Scrap Mechanic\User"
        $rawItems = @()

        if (Test-Path $userDir) {
            $rawItems = Get-ChildItem -Path "$userDir\User_*\Save\Survival" -Filter "*.db" -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.Extension -eq ".db" }
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

            $saveObjects += [PSCustomObject]@{
                Path    = $item.FullName
                Name    = $item.Name
                Account = $accName
            }
        }

        # If no saves found anywhere
        if ($saveObjects.Count -eq 0) {
            Clear-Host
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host "         Scrap Mechanic Fant Migration Tool" -ForegroundColor Cyan
            Write-Host "                By Linus and Gemini" -ForegroundColor DarkCyan
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "[!] No Survival save files found in standard AppData paths.`n" -ForegroundColor Yellow
            Write-Host "  [O] Open the save game directory" -ForegroundColor White
            Write-Host "  [M] Manual input / Drag & Drop a .db file`n" -ForegroundColor White

            $choice = Read-Host "Select 'O' or 'M'"
            if ($choice -eq 'O' -or $choice -eq 'o') {
                if (Test-Path $userDir) { Start-Process explorer.exe -ArgumentList "`"$userDir`"" }
                Read-Host "Press Enter to re-scan saves..."
                continue
            }
            if ($choice -eq 'M' -or $choice -eq 'm') {
                $rawInput = Read-Host "`nDrag and drop your .db save file here and press Enter"
                $selectedPath = $rawInput.Trim('"').Trim("'")
                if (Test-Path $selectedPath) { return $selectedPath }
                Write-Host "`n[ERROR] Invalid file path!" -ForegroundColor Red
                Read-Host "Press Enter to try again..."
                continue
            }
            continue
        }

        # Group saves by Steam Account
        $groupedUsers = $saveObjects | Group-Object Account
        $selectedUserGroup = $null

        # STEP 1: USER SELECTION (Auto-bypassed if only 1 user exists)
        if ($groupedUsers.Count -eq 1) {
            # FAILSAFE: Only 1 user exists on PC, skip user prompt
            $selectedUserGroup = $groupedUsers[0]
        } else {
            Clear-Host
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host "         Scrap Mechanic Fant Migration Tool" -ForegroundColor Cyan
            Write-Host "                By Linus and Gemini" -ForegroundColor DarkCyan
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Found $($groupedUsers.Count) Steam profiles with Survival save files:`n" -ForegroundColor Green

            for ($u = 0; $u -lt $groupedUsers.Count; $u++) {
                $usr = $groupedUsers[$u]
                Write-Host "  [$($u+1)] $($usr.Name) " -NoNewline -ForegroundColor Yellow
                Write-Host "($($usr.Count) save file(s))" -ForegroundColor Gray
            }

            Write-Host ""
            Write-Host "  [O] Open the save game directory" -ForegroundColor White
            Write-Host "  [M] Manual input / Drag & Drop a .db file`n" -ForegroundColor White
            Write-Host "  picking a file will not touch the vanilla file in any way" -ForegroundColor Gray
            Write-Host "  every edit on the selected file will be done on a copy`n" -ForegroundColor Gray

            $userChoice = Read-Host "Select a user profile number (1-$($groupedUsers.Count)), 'O', or 'M'"

            if ($userChoice -eq 'O' -or $userChoice -eq 'o') {
                $openDir = Split-Path $saveObjects[0].Path
                if (Test-Path $openDir) { Start-Process explorer.exe -ArgumentList "`"$openDir`"" }
                Read-Host "Press Enter to re-scan saves..."
                continue
            }

            if ($userChoice -eq 'M' -or $userChoice -eq 'm') {
                $rawInput = Read-Host "`nDrag and drop your .db save file here and press Enter"
                $selectedPath = $rawInput.Trim('"').Trim("'")
                if (Test-Path $selectedPath) { return $selectedPath }
                Write-Host "`n[ERROR] Invalid file path!" -ForegroundColor Red
                Read-Host "Press Enter to try again..."
                continue
            }

            if ($userChoice -match '^\d+$') {
                $uIdx = [int]$userChoice - 1
                if ($uIdx -ge 0 -and $uIdx -lt $groupedUsers.Count) {
                    $selectedUserGroup = $groupedUsers[$uIdx]
                }
            }

            if (-not $selectedUserGroup) {
                Write-Host "`n[ERROR] Invalid profile selection!" -ForegroundColor Red
                Read-Host "Press Enter to try again..."
                continue
            }
        }

        # STEP 2: SAVE FILE SELECTION (For selected user)
        while ($true) {
            Clear-Host
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host "         Scrap Mechanic Fant Migration Tool" -ForegroundColor Cyan
            Write-Host "                By Linus and Gemini" -ForegroundColor DarkCyan
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Profile: $($selectedUserGroup.Name)" -ForegroundColor Green
            Write-Host "Found $($selectedUserGroup.Count) Survival save file(s):`n" -ForegroundColor Gray

            $userSaves = $selectedUserGroup.Group
            for ($s = 0; $s -lt $userSaves.Count; $s++) {
                Write-Host "  [$($s+1)] $($userSaves[$s].Name)" -ForegroundColor Yellow
            }

            Write-Host ""
            if ($groupedUsers.Count -gt 1) {
                Write-Host "  [B] Back to user profile selection" -ForegroundColor Cyan
            }
            Write-Host "  [O] Open the save game directory" -ForegroundColor White
            Write-Host "  [M] Manual input / Drag & Drop a .db file`n" -ForegroundColor White
            Write-Host "  picking a file will not touch the vanilla file in any way" -ForegroundColor Gray
            Write-Host "  every edit on the selected file will be done on a copy`n" -ForegroundColor Gray

            $promptText = "Select a save file number (1-$($userSaves.Count))"
            if ($groupedUsers.Count -gt 1) { $promptText += ", 'B'" }
            $promptText += ", 'O', or 'M'"

            $saveChoice = Read-Host $promptText

            if ($groupedUsers.Count -gt 1 -and ($saveChoice -eq 'B' -or $saveChoice -eq 'b')) {
                break # Return to Step 1 (User Selection)
            }

            if ($saveChoice -eq 'O' -or $saveChoice -eq 'o') {
                $openDir = Split-Path $userSaves[0].Path
                if (Test-Path $openDir) { Start-Process explorer.exe -ArgumentList "`"$openDir`"" }
                Read-Host "Press Enter to re-scan saves..."
                break
            }

            if ($saveChoice -eq 'M' -or $saveChoice -eq 'm') {
                $rawInput = Read-Host "`nDrag and drop your .db save file here and press Enter"
                $selectedPath = $rawInput.Trim('"').Trim("'")
                if (Test-Path $selectedPath) { return $selectedPath }
                Write-Host "`n[ERROR] Invalid file path!" -ForegroundColor Red
                Read-Host "Press Enter to try again..."
                continue
            }

            if ($saveChoice -match '^\d+$') {
                $sIdx = [int]$saveChoice - 1
                if ($sIdx -ge 0 -and $sIdx -lt $userSaves.Count) {
                    return $userSaves[$sIdx].Path
                }
            }

            Write-Host "`n[ERROR] Invalid save selection!" -ForegroundColor Red
            Read-Host "Press Enter to try again..."
        }
    }
}

$sourceSave = Show-SaveMenu

Write-Host "`nSource Save: `"$sourceSave`"" -ForegroundColor Cyan

# 3. Copy save file to Custom directory safely per Steam Profile
Write-Host "`n[1/3] Copying save to Custom folder..." -ForegroundColor Gray

$targetSave = $sourceSave
if ($sourceSave -match '(?i)\\Save\\Survival\\') {
    $targetSave = [regex]::Replace($sourceSave, '(?i)\\Save\\Survival\\', '\Save\Custom\')
    $targetDir = Split-Path $targetSave
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    Copy-Item -Path $sourceSave -Destination $targetSave -Force
    Write-Host "   Save copied to: `"$targetSave`"" -ForegroundColor Green
    Write-Host "   Original Survival save left untouched in Survival folder.`n" -ForegroundColor DarkGray
} else {
    Write-Host "   File is outside standard Survival folder. Creating backup copy (.db.bak)..." -ForegroundColor Yellow
    Copy-Item -Path $sourceSave -Destination "$sourceSave.bak" -Force
}

# 4. Execute Core SQL Migration
Write-Host "[2/3] Executing SQL Database Migration..." -ForegroundColor Gray

$tempSql = Join-Path $env:TEMP "sm_migrate_temp.sql"
$sqlQueries = @"
UPDATE Game SET flags = 15, mods = X'0000000100000000E0E1EF6B5C6453510B28F576470573F9A9361B19' WHERE savegameversion = 28 AND flags = 14 AND mods = X'00000000';
UPDATE ScriptData SET uid = X'B6E35C9767BF5555A519A066E14A8C1E' WHERE uid = X'2C3699B2FD9C503EA405CF73434E2E88';
UPDATE ScriptData SET data = X'B6E35C9767BF5555A519A066E14A8C1E' || SUBSTR(data, 17) WHERE uid = X'B6E35C9767BF5555A519A066E14A8C1E' AND SUBSTR(data, 1, 16) = X'2C3699B2FD9C503EA405CF73434E2E88';
"@

Set-Content -Path $tempSql -Value $sqlQueries -Encoding UTF8
Get-Content $tempSql | & $sqliteBin "$targetSave"
if (Test-Path $tempSql) { Remove-Item $tempSql }

Write-Host "   SQL Migration applied successfully.`n" -ForegroundColor Green

# 5. Scan and Rebuild Container BLOBs
Write-Host "[3/3] Scanning and Rebuilding Player Inventory Containers..." -ForegroundColor Gray

try {
    $rows = & $sqliteBin "$targetSave" "SELECT id, hex(data) FROM Container;"
} catch {
    Write-Host "[ERROR] Failed to query Container table: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit
}

if (-not $rows) {
    Write-Host "   [!] Container table is empty." -ForegroundColor Yellow
} else {
    $rowCount = ($rows | Measure-Object).Count
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

        # Match ONLY 40-slot player containers (ignoring 30-slot world chests)
        if ($currentSize -eq 40) {
            Write-Host "   [MATCH] Player Inventory ID $id detected (40 slots) -> Expanding to 60 slots..." -ForegroundColor Yellow
            
            $neededSlots = 60 - $currentSize
            $header = $hex.Substring(0, 14)
            $newSizeHex = "003C"
            $stackSize = $hex.Substring(18, 4)
            $itemsLen = $currentSize * 44
            $requiredLen = 22 + $itemsLen

            if ($requiredLen -gt $hex.Length) {
                Write-Host "      [ERROR] Container ID $id offset overflow! Skipping!" -ForegroundColor Red
                continue
            }

            $items = $hex.Substring(22, $itemsLen)
            $emptySlot = "00000000000000000000000000000000ffffffff0000"
            $padding = $emptySlot * $neededSlots
            $tailIndex = 22 + $itemsLen
            $tail = $hex.Substring($tailIndex)

            $patchedHex = $header + $newSizeHex + $stackSize + $items + $padding + $tail
            $updateSql = "UPDATE Container SET data = x'$patchedHex' WHERE id = $id;"

            & $sqliteBin "$targetSave" "$updateSql"
            Write-Host "      [+] SUCCESS: Expanded Container ID $id to 60 slots!" -ForegroundColor Green
            $updatedCount++
        }
    }
    Write-Host "`n   Operation Complete. Total player inventories expanded: $updatedCount" -ForegroundColor Cyan
}

# 6. Final Status
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  SUCCESS! Save migrated and placed in Custom Game menu." -ForegroundColor Green
Write-Host "  Credits to `"taswin`" on the fant mod discord for" -ForegroundColor Green
Write-Host "  finding a reliable method on converting a save and" -ForegroundColor Green
Write-Host "  gemini for helping in 99% of the coding for this tool" -ForegroundColor Green
Write-Host "  Path: `"$targetSave`"" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green

Write-Host ""
Read-Host "Press Enter to exit..."