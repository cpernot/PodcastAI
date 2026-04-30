param(
    [string]$targetFileName
)

# Fix encoding for terminal output (emojis/mojibake)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$bucket = "gs://ai-g-course-podcast"
$localAudioDir = "c:\Users\owner\Documents\PodcastAI\audio_files"
$xmlFile = "c:\Users\owner\Documents\PodcastAI\podcast7.xml"
$indexFile = "c:\Users\owner\Documents\PodcastAI\index.txt"

Write-Host "[START] Starting deployment to $bucket..." -ForegroundColor Cyan

# 0. Load Index Metadata
$metadata = @{}
if (Test-Path $indexFile) {
    $lines = [System.IO.File]::ReadAllLines($indexFile, [System.Text.Encoding]::UTF8) | Where-Object { $_.Trim() -ne "" }
    for ($i = 0; $i -lt $lines.Count; $i += 3) {
        if ($i + 2 -lt $lines.Count) {
            $id = $lines[$i].Trim().ToUpper()
            $rawTitle = $lines[$i+1].Trim()
            $desc = $lines[$i+2].Trim()
            
            $shortTitle = $rawTitle
            if ($shortTitle.Length -gt 25) { $shortTitle = $shortTitle.Substring(0, 22) + "..." }
            
            $metadata[$id] = @{ Title = $shortTitle; Desc = $desc }
        }
    }
}

# 1. Automate RSS Feed Update
Write-Host "Checking for new episodes to add to RSS..." -ForegroundColor Yellow
$xmlContent = [System.IO.File]::ReadAllText($xmlFile, [System.Text.Encoding]::UTF8)
$newFiles = Get-ChildItem "$localAudioDir\*.m4a" | Sort-Object Name

foreach ($file in $newFiles) {
    $fileName = $file.Name
    $unitId = $fileName.Replace(".m4a", "").ToUpper()
    
    $titleText = "New Episode"
    $description = "Automatic entry for $fileName"
    
    if ($metadata.ContainsKey($unitId)) {
        $titleText = $metadata[$unitId].Title
        $description = $metadata[$unitId].Desc
    }
    
    $fullTitle = "${unitId}: $titleText"

    # 1.1 Calculate deterministic pubDate based on unit number for correct ordering
    # Each unit gets a unique day starting from Jan 1st 2024.
    # Higher unit numbers will have later dates, appearing at the top in podcast apps.
    $unitNumberMatch = [regex]::Match($fileName, 'u(\d+)')
    if ($unitNumberMatch.Success) {
        $unitVal = [int]$unitNumberMatch.Groups[1].Value
        $baseDate = Get-Date -Year 2024 -Month 1 -Day 1 -Hour 12 -Minute 0 -Second 0
        $pubDateObj = $baseDate.AddDays($unitVal)
        $pubDate = $pubDateObj.ToUniversalTime().ToString("ddd, dd MMM yyyy HH:mm:ss 'GMT'", [System.Globalization.CultureInfo]::InvariantCulture)
    } else {
        $pubDate = [DateTime]::UtcNow.ToString("ddd, dd MMM yyyy HH:mm:ss 'GMT'", [System.Globalization.CultureInfo]::InvariantCulture)
    }

    if ($xmlContent -notlike "*$fileName*") {
        Write-Host "Adding $fileName to RSS feed..." -ForegroundColor Green
        
        $newItem = @"

    <item>
      <title>$fullTitle</title>
      <description>$description</description>
      <pubDate>$pubDate</pubDate>
      <enclosure url="https://storage.googleapis.com/ai-g-course-podcast/$fileName" length="0" type="audio/x-m4a"/>
      <guid isPermaLink="false">unit_$($fileName.Replace(".m4a", ""))</guid>
    </item>
"@
        $xmlContent = $xmlContent.Replace("<itunes:category text=""Education""/>", "<itunes:category text=""Education""/>`n$newItem")
    } else {
        # Update existing item (Title, Description, and Date for ordering)
        $escapedFileName = [regex]::Escape($fileName)
        $pattern = "(?s)<item>(?:(?!<item>).)*?<enclosure url=`"[^`"]*?$escapedFileName`".*?</item>"
        $match = [regex]::Match($xmlContent, $pattern)
        
        if ($match.Success) {
            $oldItem = $match.Value
            $newItem = $oldItem -replace "<title>.*?</title>", "<title>$fullTitle</title>"
            $newItem = $newItem -replace "<description>.*?</description>", "<description>$description</description>"
            $newItem = $newItem -replace "<pubDate>.*?</pubDate>", "<pubDate>$pubDate</pubDate>"
            
            if ($oldItem -ne $newItem) {
                Write-Host "[UPDATE] Updating metadata/order for $fileName..." -ForegroundColor Gray
                $xmlContent = $xmlContent.Replace($oldItem, $newItem)
            }
        }
    }
}

$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($xmlFile, $xmlContent, $utf8NoBOM)

# 2. Sync to GCS
if ($targetFileName -and (Test-Path "$localAudioDir\$targetFileName")) {
    Write-Host "[UPLOAD] Uploading $targetFileName..." -ForegroundColor Yellow
    gcloud storage cp "$localAudioDir\$targetFileName" "$bucket/" -q
} else {
    Write-Host "[SYNC] Syncing all audio files using rsync..." -ForegroundColor Yellow
    # rsync only uploads what's new or changed.
    gcloud storage rsync "$localAudioDir" "$bucket" --include-regex=".*\.m4a$" -q
}

# Always sync and update XML
Write-Host "[RSS] Syncing RSS feed..." -ForegroundColor Yellow
gcloud storage cp $xmlFile "$bucket/" -q

Write-Host "[DONE] Deployment complete!" -ForegroundColor Green
