param (
    [Parameter(Mandatory=$true)]
    [string]$unitNum
)

# Fix encoding for terminal output (emojis/mojibake)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$downloadsPath = Join-Path $env:USERPROFILE "Downloads"
$cachePath = "C:\automation_chrome\Default\Cache\Cache_Data"
$destFolder = "c:\Users\owner\Documents\PodcastAI\audio_files"
$destFile = "g-u$unitNum.m4a"
$destPath = Join-Path $destFolder $destFile

if (-not (Test-Path $destFolder)) { New-Item -ItemType Directory -Path $destFolder }

Write-Host "[SEARCH] Searching for Unit $unitNum audio..." -ForegroundColor Cyan

# 1. Try Downloads Folder first (Edge/Manual download)
$downloadFile = Get-ChildItem -Path $downloadsPath -Filter "*.m4a" | 
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-60) } |
                Sort-Object LastWriteTime -Descending | 
                Select-Object -First 1

if ($downloadFile) {
    Write-Host "[OK] Found Downloaded Audio in Downloads: $($downloadFile.Name) ($($downloadFile.LastWriteTime))" -ForegroundColor Green
    Copy-Item -Path $downloadFile.FullName -Destination $destPath -Force
    Write-Host "[COPY] Copied to: $destPath" -ForegroundColor Yellow
    
    Write-Host "[DEPLOY] Starting deployment for $destFile..." -ForegroundColor Cyan
    .\deploy_podcast.ps1 -targetFileName $destFile
    exit
}

# 2. Fallback to Cache (Chrome Automation)
Write-Host "[INFO] No recent downloads found. Searching in browser cache..." -ForegroundColor Gray

# Find newest files in cache that are between 30MB and 45MB
$files = Get-ChildItem -Path $cachePath -File | 
         Where-Object { $_.Length -gt 30MB -and $_.Length -lt 45MB } | 
         Sort-Object LastWriteTime -Descending | 
         Select-Object -First 5

if (-not $files) {
    Write-Error "[ERROR] No matching files found in Downloads or Cache. Try playing the audio for a few seconds or downloading it first."
    exit
}

foreach ($f in $files) {
    # Check for ftypdash signature (hex: 00 00 00 18 66 74 79 70 64 61 73 68)
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $hex = [System.BitConverter]::ToString($bytes, 0, 12) -replace '-'
    
    if ($hex -like "*6674797064617368*") { # "ftypdash"
        Write-Host "[OK] Found Unit Audio in Cache: $($f.Name) ($($f.LastWriteTime))" -ForegroundColor Green
        
        Copy-Item -Path $f.FullName -Destination $destPath -Force
        Write-Host "[COPY] Copied to: $destPath" -ForegroundColor Yellow
        
        Write-Host "[DEPLOY] Starting deployment for $destFile..." -ForegroundColor Cyan
        .\deploy_podcast.ps1 -targetFileName $destFile
        exit
    }
}

Write-Error "[ERROR] Found large files in cache but none matched the audio signature (ftypdash)."
