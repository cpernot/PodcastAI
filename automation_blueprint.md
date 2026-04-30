# PodcastAI: NotebookLM Automation Blueprint (V1.0)

## 1. The Challenge
NotebookLM presents three major hurdles for traditional automation:
*   **Authentication**: Standard logins are blocked by Google's anti-bot systems.
*   **Hidden Downloads**: Audio files are generated as memory-only "Blobs" that do not appear in standard folders.
*   **Automation Detection**: The UI may become unresponsive when it detects script control.

## 2. Our Solution: The "CDP Bridge"
We use a **Hybrid Assistant** model:
1.  **Persistent Profile**: All sessions live in `C:\automation_chrome`.
2.  **CDP Connection**: Chrome runs on `--remote-debugging-port=9222`.
3.  **Cache Extraction**: We identify the audio file by searching for the `ftypdash` hex signature in `C:\automation_chrome\Default\Cache\Cache_Data\`.

## 3. Recommended Workflow
1.  **Launch**: Use `start_automation_chrome.bat`.
2.  **Generate**: Manually click "Generate" in NotebookLM.
3.  **Extract & Deploy**: Run the extraction script (details below).

---
*Created by Antigravity - 2026-04-29*
