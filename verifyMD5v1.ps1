# Parameters
$RootPath = Get-Location
$LogDir   = Join-Path $RootPath "Misc\Logs"
$LogFile  = Join-Path $LogDir "verifyMD5.log"
$CreateMissing = $true

# Configuration
$FileTypes = @("*.gho", "*.iso", "*.img", "*.zip")
$ExcludeList = @("Misc", "Temp")

# Ensure Logs directory exists
if (!(Test-Path $LogDir)) { 
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null 
}

# Initialize Log
$StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"`n--- Hash Check Started: $StartTime ---" | Out-File $LogFile -Append

# 1. Get ONLY subdirectories (excluding Misc/Temp), then recurse for files
# 2. Recurse for the specific image types
# 3. EXPLICITLY filter out any .md5 files so they aren't processed as images
$Files = Get-ChildItem -Path $RootPath -Directory -Exclude $ExcludeList | 
         Get-ChildItem -Recurse -File -Include $FileTypes |
         Where-Object { $_.Extension -ne ".md5" }

foreach ($File in $Files) {
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $BaseName  = $File.BaseName
    $MD5Path   = Join-Path $File.DirectoryName "$BaseName.md5"
    
    Write-Host "[$TimeStamp] Processing: $($File.Name)" -ForegroundColor Cyan

    if (Test-Path $MD5Path) {
        # READ: Get first line
        $md5Line = (Get-Content $MD5Path -First 1 -ErrorAction SilentlyContinue)
        
        if (-not [string]::IsNullOrWhiteSpace($md5Line)) {
            # FIXED SYNTAX: .Trim() is a method, -split is an operator
            $ExpectedHash = ($md5Line.Trim() -split '\s+')[0]
            
            if ($ExpectedHash -match '^[a-fA-F0-9]{32}$') {
                # VERIFY
                $ActualHash = (Get-FileHash $File.FullName -Algorithm MD5).Hash

                if ($ActualHash -eq $ExpectedHash) {
                    $Status = "PASS"
                    $Color  = "Green"
                } else {
                    $Status = "FAIL (Mismatch)"
                    $Color  = "Red"
                }
            } else {
                $Status = "ERROR (Invalid MD5 Format)"
                $Color  = "Magenta"
            }
        } else {
            $Status = "ERROR (MD5 File Empty)"
            $Color  = "Red"
        }
    } 
    elseif ($CreateMissing) {
        # CREATE
        $ActualHash = (Get-FileHash $File.FullName -Algorithm MD5).Hash
        "$ActualHash  $($File.Name)" | Out-File $MD5Path
        $Status = "CREATED MD5"
        $Color  = "Yellow"
    } else {
        $Status = "SKIPPED (No MD5)"
        $Color  = "Gray"
    }

    # LOG and Output
    $LogEntry = "[$TimeStamp] $Status | $($File.FullName)"
    $LogEntry | Out-File $LogFile -Append
    Write-Host "  -> $Status" -ForegroundColor $Color
}

Write-Host "Check complete. Log updated: $LogFile" -ForegroundColor Magenta
