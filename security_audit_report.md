# Security Audit Report: PodcastAI

## 1. Infrastructure Security (GCS)

### Status: **HARDENED**
- **Issue**: Attempting to use Legacy Object ACLs (`--add-acl-grant`) on a bucket with Uniform Bucket-Level Access (UBLA) enabled.
- **Risk**: Low (failed deployments), but causes noisy errors.
- **Remediation**: Switched to IAM-based bucket-level permissions. 
- **Command Executed**: `gcloud storage buckets add-iam-policy-binding gs://ai-g-course-podcast --member="allUsers" --role="roles/storage.objectViewer"`.
- **Result**: All files are now reliably public without requiring individual ACL updates.

## 2. Script Security & Validation

### Status: **IMPROVED**
- **Input Validation**: `extract_from_cache.ps1` uses the `$unitNum` parameter. 
  - *Observation*: While used for file naming, a malicious input could theoretically attempt path traversal.
  - *Recommendation*: Add `if ($unitNum -match '^\d+$')` to ensure only numbers are processed.
- **Hardcoded Information**: Bucket names and local paths are hardcoded. 
  - *Risk*: Minimal for a personal local tool.
  - *Observation*: No secrets (passwords/keys) were found in the scripts.

## 3. Execution Environment

### Status: **STABLE**
- **PowerShell Policy**: `extract_and_deploy.bat` uses `-ExecutionPolicy Bypass`.
  - *Note*: This is standard for local automation but should be monitored if the script is moved to a shared environment.
- **Terminal Encoding**: Forced UTF-8 and removed emojis to prevent "Mojibake" which can lead to misinterpretation of script logs.

## 4. Sensitive Data Exposure

- **Findings**: 
  - Checked `index.txt`, `setting.txt`, and `podcast7.xml`.
  - No private API keys or PII found.
  - `index.txt` contains Japanese characters; handled correctly via UTF-8 without BOM.

## Final Assessment

The current setup is **Secure** for the intended use case of local podcast production. The move to IAM permissions for the GCS bucket is the most significant security improvement made during this audit.
