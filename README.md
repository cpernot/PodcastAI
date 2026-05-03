# PodcastAI: Unit Extraction & Deployment

This project automates the extraction of audio files from your browser (Downloads/Cache) and deploys them to the Google Cloud Storage podcast feed.

## 🚀 Quick Start: Extract & Deploy
The easiest way to add a new episode is using the batch script:
1.  Generate/Download your audio in **NotebookLM** (using Edge or Chrome).
2.  Double-click **`extract_and_deploy.bat`**.
3.  Enter the **Unit Number** (e.g., `038`).
4.  The script will automatically find the file, rename it, update the RSS feed, and upload it to the cloud.

## 📡 Automation Options

### 1. Semi-Automatic (Recommended)
Use `extract_and_deploy.bat` whenever you have a new unit. It handles extraction, renaming, and cloud sync in one go.

### 2. Full Background Watcher
If you want to watch the `audio_files/` folder and deploy automatically whenever a file is added:
```powershell
Start-Job -FilePath .\watch_and_deploy.ps1 -Name "PodcastDeployWatcher"
```

### 3. Manual Sync
To sync all local files and the RSS feed to GCS without extracting anything new:
```powershell
.\deploy_podcast.ps1
```

## 🛠️ Status & Monitoring
- **Logs**: Check `deploy_log.txt` for a history of all deployments.
- **RSS Feed**: View/Edit `podcast9.xml` to manage episode metadata.
- **Ordering**: The feed is automatically sorted by **Unit Number** (newest first).

## 📱 Troubleshooting iPhone Deployment
Podcast apps on iOS (like Apple Podcasts) are aggressive at caching RSS feeds and audio files. If you update an episode's audio or metadata but don't see the changes on your phone, use the **"Cache Buster"** method:

### The "Cache Buster" Method
To force a refresh, you must change the URLs that the podcast app tracks:
1.  **Rename the XML file**: Increment the version (e.g., from `podcast8.xml` to `podcast9.xml`).
2.  **Rename the Audio files**: Add a suffix (e.g., `g-u001_episode.m4a`).
3.  **Update the Feed**: Ensure the `<enclosure>` tags point to the new filenames.
4.  **Update atom:link**: Ensure the `<atom:link rel="self">` in the XML matches the new cloud URL.

The `deploy_podcast.ps1` script is currently configured to handle the `_episode.m4a` suffix and target `podcast9.xml` automatically.

### Check xml file structure
use: https://www.castfeedvalidator.com/

## 🔒 Security & Permissions
Ensure you have run the following once to make the bucket public:
```powershell
gcloud storage buckets add-iam-policy-binding gs://ai-g-course-podcast --member="allUsers" --role="roles/storage.objectViewer"
```
