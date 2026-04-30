# PodcastAI Agents

## Audio Deployment Agent
- **Mission**: Automatically deploy new audio files from the `audio_files/` directory to Google Cloud Storage and update the `podcast7.xml` feed.
- **Target Bucket**: `ai-g-course-podcast` (GCP Project: `project-b93d012c-f4f2-42f4-a1e`)
- **Required Configuration**:
    - [x] GCP Project ID: `project-b93d012c-f4f2-42f4-a1e`
    - [x] GCS Bucket Name confirmation: `ai-g-course-podcast`
    - [x] GCS Permissions: **Uniform Bucket-Level Access (IAM)**. `allUsers` must have `roles/storage.objectViewer`.
- **Deployment Strategy**:
    1. **Extraction**: Use `extract_from_cache.ps1` to pull audio from `Downloads` (Edge) or Chrome Cache.
    2. **Trigger**: Run `.\deploy_podcast.ps1 -targetFileName <name>` for targeted, efficient uploads.
    3. **Ordering**: Deterministic `pubDate` calculation based on Unit Number to ensure reverse-unit ordering in apps.
    4. **Persistence**: `watch_and_deploy.ps1` monitors for changes if background automation is desired.

## Engineering Standards (Internationalization & Encoding)
- **Primary Encoding**: All text files (XML, PS1, MD, TXT) MUST be saved in **UTF-8 without BOM**.
- **PowerShell Precautions**: 
    - Use `[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))` for writes.
    - Set `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` in all scripts to prevent Mojibake.
- **Kanji/Multi-byte Handling**: 
    - Ensure all XML files have `<?xml version="1.0" encoding="UTF-8"?>`.
    - Use `InvariantCulture` for RSS `pubDate` formatting.
- **Terminal UI**: Avoid emojis in scripts to ensure maximum compatibility across different Windows terminal environments.
- **Validation**: After any automated edit to `podcast7.xml`, verify that the structure is valid and the unit-based order is maintained.