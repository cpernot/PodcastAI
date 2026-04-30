$rootPath = "c:\Users\owner\Documents\PodcastAI"
$folder = "$rootPath\audio_files"
$filter = "*.m4a"
$logFile = "$rootPath\deploy_log.txt"

# Tracking to prevent rapid double-triggering
$global:lastRun = @{}
$global:isBusy = $false

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

function Test-FileReady {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    try {
        $file = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
        $file.Close()
        return $true
    }
    catch {
        return $false
    }
}

if (-not (Test-Path $folder)) {
    Write-Log "ERROR: Folder $folder not found. Watcher exiting."
    exit
}

$fsw = New-Object IO.FileSystemWatcher $folder, $filter
$fsw.IncludeSubdirectories = $false
$fsw.EnableRaisingEvents = $true

$action = {
    $name = $Event.SourceEventArgs.Name
    $fullPath = $Event.SourceEventArgs.FullPath
    $changeType = $Event.SourceEventArgs.ChangeType
    $now = Get-Date

    # 1. Debounce: Strictly ignore the same file for 60 seconds after a trigger
    if ($global:lastRun.ContainsKey($name) -and ($now - $global:lastRun[$name]).TotalSeconds -lt 60) {
        return
    }

    # 2. Global Lock: One deploy at a time
    if ($global:isBusy) {
        return
    }

    $global:isBusy = $true
    $global:lastRun[$name] = $now
    
    try {
        Write-Log "EVENT: $changeType detected for $name. Waiting for file to be ready..."
        
        # 3. Wait for file to be released (up to 30 seconds)
        $ready = $false
        for ($i = 0; $i -lt 30; $i++) {
            if (Test-FileReady $fullPath) {
                $ready = $true
                break
            }
            Start-Sleep -Seconds 1
        }

        if (-not $ready) {
            Write-Log "SKIP: File $name is still locked after 30s. Aborting this trigger."
            return
        }

        # 4. Settle time
        Start-Sleep -Seconds 2
        
        Write-Log "START: Deploying $name..."
        & "c:\Users\owner\Documents\PodcastAI\deploy_podcast.ps1" 2>&1 | ForEach-Object { Write-Log "DEPLOY: $_" }
        Write-Log "SUCCESS: Deployment finished."
    }
    catch {
        Write-Log "ERROR: Deployment failed. $($_.Exception.Message)"
    }
    finally {
        # 5. Cooldown before allowing another deployment
        Start-Sleep -Seconds 5
        $global:isBusy = $false
    }
}

$onCreated = Register-ObjectEvent $fsw Created -Action $action
$onChanged = Register-ObjectEvent $fsw Changed -Action $action

Write-Log "Watcher started (Robust Mode). Monitoring $folder..."

try {
    while ($true) {
        Start-Sleep -Seconds 60
    }
}
finally {
    Unregister-Event -SourceIdentifier $onCreated.Name
    Unregister-Event -SourceIdentifier $onChanged.Name
    Write-Log "Watcher stopped safely."
}
