# Parameters
$RootPath = Get-Location
$sessionStartTime = Get-Date

# Setup Logging
$logDir = Join-Path $RootPath "Misc\Logs"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "CopyVerify_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log($msg, $color = "White", $status = "INFO") {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$status] $msg"
    Write-Host $logEntry -ForegroundColor $color
    $logEntry | Out-File -FilePath $logFile -Append
}

# 1. Get Subfolders (Excluding log and temp directories)
$folders = Get-ChildItem -Path $RootPath -Directory | Where-Object { $_.Name -notmatch "Misc|Temp" -or ($_.Name -eq "Misc") }
if ($folders.Count -eq 0) { Write-Log "No valid subfolders found." "Yellow" "WARN"; exit }

# 2. Display Selection UI
Write-Host "`nAvailable Folders for Migration:" -ForegroundColor Cyan
for ($i = 0; $i -lt $folders.Count; $i++) {
    Write-Host ("[{0}] {1}" -f ($i + 1), $folders[$i].Name)
}

$destBase = Read-Host "`nEnter destination path (e.g., E:\)"
$selectionInput = Read-Host "Enter numbers (space separated) or 'all'"
$selection = if ($selectionInput -eq "all") { $folders } else { 
    $indices = $selectionInput.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { [int]$_ - 1 }
    $folders[$indices] 
}

Write-Log "Migration Started. Target: $destBase" "Cyan" "START"

# 3. Process Selected Folders
foreach ($folder in $selection) {
    if (!$folder) { continue }
    $targetPath = Join-Path $destBase $folder.Name
    $isVerifiedOnly = $false

    # Check if folder exists at destination
    if (Test-Path $targetPath) {
        $choice = Read-Host "`n[$($folder.Name)] Exists at destination. Verify existing only? (y/n)"
        if ($choice -eq 'y') { $isVerifiedOnly = $true }
    }

    # Perform Copy (if not verify-only)
    if (-not $isVerifiedOnly) {
        $copyStart = Get-Date
        try {
            Write-Log "Copying: $($folder.Name)" "White" "COPY"
            Copy-Item -Path $folder.FullName -Destination $destBase -Recurse -Force -ErrorAction Stop
            $dur = ((Get-Date) - $copyStart).ToString("hh\:mm\:ss")
            Write-Log "Copy SUCCESS ($dur)" "Green" "PASS"
        } catch {
            Write-Log "Copy FAILED for $($folder.Name): $($_.Exception.Message)" "Red" "FAIL"; continue
        }
    }

    # 4. Recursive Verification & Auto-Repair
    $currentFlag = if ($isVerifiedOnly) { "VERIFY-ONLY" } else { "POST-VERIFY" }
    
    # Hunt for all .md5 files in the destination subfolder
    $allMD5s = Get-ChildItem -Path $targetPath -Filter "*.md5" -Recurse
    
    if ($allMD5s.Count -eq 0) {
        Write-Log "No MD5 files found in $($folder.Name) to verify." "Yellow" "WARN"
    }

    foreach ($md5File in $allMD5s) {
        $md5Line = Get-Content $md5File.FullName | Select-Object -First 1
        
        # Parse MD5 [Hash][Spaces][Filename]
        if ($md5Line -match '^([a-fA-F0-9]{32})\s+(.+)$') {
            $expectedHash = $Matches[1]
            $expectedName = $Matches[2].Trim()
            $verifyPath = Join-Path $md5File.DirectoryName $expectedName

            # REPAIR: Handle naming mismatches (like the IPPM_ prefix issue)
            if (!(Test-Path $verifyPath)) {
                # Look for any file in the same folder that isn't an .md5
                $altFile = Get-ChildItem $md5File.DirectoryName -File | Where-Object { $_.Name -notmatch ".md5$" } | Select-Object -First 1
                if ($altFile) { 
                    $verifyPath = $altFile.FullName
                    $expectedName = $altFile.Name 
                }
            }

            if (Test-Path $verifyPath) {
                Write-Log "Verifying: $($md5File.Directory.Name)\$expectedName" "Yellow" $currentFlag
                $actualHash = (Get-FileHash $verifyPath -Algorithm MD5).Hash
                
                if ($actualHash -eq $expectedHash) {
                    Write-Log "PASS: $expectedName integrity confirmed." "Green" "OK"
                    
                    # Fix the .md5 file content if we used repair logic
                    if ($expectedName -ne $Matches[2].Trim()) {
                        "$expectedHash  $expectedName" | Out-File $md5File.FullName -Force
                        Write-Log "Fixed MD5 filename record in: $($md5File.Name)" "Gray" "REPAIR"
                    }
                } else {
                    Write-Log "HASH MISMATCH: $expectedName is corrupted!" "Red" "FAIL"
                }
            } else {
                Write-Log "ERROR: Target file '$expectedName' missing in $($md5File.DirectoryName)" "Red" "MISSING"
            }
        } else {
            Write-Log "MALFORMED: Could not parse MD5 file $($md5File.Name)" "Red" "ERROR"
        }
    }
}

# Summary and Exit
$totalTime = ((Get-Date) - $sessionStartTime).ToString("hh\:mm\:ss")
Write-Log "-------------------------------------------" "Cyan" "SUMMARY"
Write-Log "Session Complete. Total Time: $totalTime" "Cyan" "END"
Write-Log "Log saved to: $logFile" "Gray" "FILE"

Write-Host "`n*** ALL TASKS FINISHED ***" -ForegroundColor Green
Write-Host "Total Elapsed Time: $totalTime"
Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
