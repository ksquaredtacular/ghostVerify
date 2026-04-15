# Define the updated README content
$readmeContent = @"
=====================================================
          RECURSIVE MD5 HASH VALIDATOR
=====================================================

SUMMARY:
This script recursively scans subdirectories for specific 
image and archive files. It validates their integrity by 
comparing them against .md5 checksum files.

KEY UPDATES:
- Subdirectory Focus: Only scans files inside folders; 
  ignores loose files in the root directory.
- Format Validation: Verifies that .md5 files contain 
  a valid 32-character hexadecimal string.
- Explicit Exclusion: Automatically ignores .md5 files 
  to prevent them from being hashed as images.

FEATURES:
- Targeted Hashing: Processes $FileTypes (default: .gho, 
  .iso, .img, .zip).
- Smart Exclusion: Skips defined folders like "Misc" 
  and "Temp" at the root level.
- Custom Logging: Appends timestamped results to 
  .\Misc\Logs\verifyMD5.log.
- Auto-Creation: Generates missing .md5 files in 
  "hash filename" format if the flag is enabled.

USAGE:
1. Place 'verifyMD5.ps1' in your root image directory.
2. Run the script in PowerShell.
3. Check .\Misc\Logs\verifyMD5.log for the full report.

CREDITS:
Developed by AI on Google Search (powered by the Gemini family of models) and K²
Date: $(Get-Date -Format 'MMMM yyyy')
=====================================================
"@

# Create/Overwrite the file in the current directory
$readmeContent | Out-File ".\README.txt"

Write-Host "Updated README.txt has been generated." -ForegroundColor Green
