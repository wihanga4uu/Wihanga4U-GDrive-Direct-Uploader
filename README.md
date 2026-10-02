# Wihanga4U GDrive Direct Uploader

## Version 1.2

- Added built-in **Client ID / Client Secret Help**.
- At the Client ID prompt, type `H` to see the complete Google Cloud Console path.
- Added `GOOGLE_OAUTH_HELP.txt` for users who want a standalone guide.
- Client Secret entry remains hidden.


## Version 1.1

- Fixed first-run Windows PowerShell issue where rclone's harmless `config file not found` notice could close the setup.
- The app now creates its local `.data/rclone.conf` automatically before first use.
- At `Remote name [gdrive]`, simply press **Enter** to use the default `gdrive` name.


**Developed by Wihanga4U**  
GitHub: https://github.com/wihanga4uu

A Windows-friendly utility for:

- downloading a **direct HTTP/HTTPS file URL straight to Google Drive**
- avoiding the need to first store the full file on the RDP/Windows disk
- splitting an existing Google Drive file into **10 GiB (or custom-size) parts**
- joining downloaded `.001`, `.002`, `.003` parts back into the original file
- automatically downloading `rclone` on first run

## Important

**Node.js / npm is NOT required.**  
This project uses Windows PowerShell + the official portable `rclone.exe`.

rclone is downloaded from:

`https://downloads.rclone.org/rclone-current-windows-amd64.zip`

(ARM64 Windows is detected automatically.)

## Quick start

1. Extract this ZIP.
2. Double-click `START.bat`.
3. Choose **1 - First-time Google Drive setup**.
4. Enter your Google OAuth **Client ID** and **Client Secret**.
5. A browser opens. Sign in to the Google Drive account and allow access.
6. Choose **2 - Direct URL -> Google Drive**.
7. Paste the direct download link, destination folder and file name.
8. After upload, choose whether to split the Drive file into parts.

For an already uploaded file, use **3 - Split existing Drive file into parts**.

## Google OAuth setup

Each user should use their own Google OAuth Desktop App.

Google Cloud steps:

1. Create/select a Google Cloud project.
2. Enable **Google Drive API**.
3. Configure Google Auth Platform / OAuth consent screen.
4. For normal personal Gmail accounts choose **External** audience.
5. Add your Google account as a test user if the app is in Testing.
6. Create an OAuth Client with application type **Desktop app**.
7. Copy the Client ID and Client Secret into this utility.

Do not put the Client Secret into GitHub.

## GitHub safety

The project includes `.gitignore`.

These local folders are intentionally ignored:

- `.data/` - contains the local `rclone.conf` OAuth configuration/token
- `.tools/` - downloaded `rclone.exe`

Never commit:

- `.data/rclone.conf`
- Client Secret
- temporary/private direct-download URLs that contain access tokens

## Splitting

The split option keeps the source Google Drive file unchanged.

Example:

```text
Downloads/
  160GB-download.zip
  Parts10GB/
    160GB-download.zip.001
    160GB-download.zip.002
    160GB-download.zip.003
    ...
```

During an active split operation, Google Drive can temporarily show names like:

```text
160GB-download.zip.001_ab12cd
```

That is normal. rclone's chunker uses temporary chunk names during the transaction and renames them after a successful completion.

Do not rename/delete active temporary chunks.

## Joining parts on a normal PC

1. Download all `.001`, `.002`, `.003` ... files into one folder.
2. Run `JOIN_PARTS.bat`.
3. Enter the folder and original file name.
4. The program verifies that part numbering is continuous, then joins them in binary mode.

You need enough free space for the final combined file in addition to the downloaded parts.

## Notes about retries

The direct upload command uses higher retry/timeout settings. However, a very large streaming upload can still need to restart if the source or upload stream breaks at a point that cannot be resumed.

If the direct URL contains an expiring token, get a new URL if the token expires.

## Sinhala quick guide

`START.bat` open karala:

- `1` -> Google Drive first setup
- Client ID + Client Secret denna
- Browser eken Google account eka Allow karanna
- `2` -> direct download URL eka Drive ekata yawanawa
- `3` -> Drive eke thiyena loku file eka 10GB (ho wena size ekakata) parts walata kadanawa
- Original file eka split karaddi delete/modify wenne naha
- `.001/.002/...` PC ekata download karala `JOIN_PARTS.bat` eken aye original file ekata join karanna puluwan

## Requirements

- Windows 10 / Windows Server 2016 or newer (for current rclone builds)
- Windows PowerShell
- Internet access
- Google Drive space
- A direct HTTP/HTTPS download URL


---

**Brand:** Wihanga4U  
**GitHub:** https://github.com/wihanga4uu
