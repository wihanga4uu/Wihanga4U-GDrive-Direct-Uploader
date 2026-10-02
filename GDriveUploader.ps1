$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsDir = Join-Path $Root ".tools"
$DataDir = Join-Path $Root ".data"
$ConfigPath = Join-Path $DataDir "rclone.conf"
$RcloneExe = Join-Path $ToolsDir "rclone.exe"

New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

# rclone prints a first-run NOTICE to stderr when the config file does not exist.
# Windows PowerShell can treat that stderr output as a terminating error when
# ErrorActionPreference is "Stop". Create an empty config file up front so
# first-time setup can continue normally.
if (-not (Test-Path $ConfigPath)) {
    New-Item -ItemType File -Force -Path $ConfigPath | Out-Null
}

function Write-Title([string]$Text) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ("  " + $Text) -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Pause-App {
    Write-Host ""
    Read-Host "Press ENTER to continue" | Out-Null
}

function Get-RcloneArgs([string[]]$Args) {
    return @("--config", $ConfigPath) + $Args
}

function Invoke-Rclone {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Arguments
    )
    & $RcloneExe --config $ConfigPath @Arguments
    return $LASTEXITCODE
}

function Ensure-Rclone {
    if (Test-Path $RcloneExe) {
        return
    }

    Write-Title "First run - downloading rclone"

    $arch = "amd64"
    if ($env:PROCESSOR_ARCHITECTURE -match "ARM64") {
        $arch = "arm64"
    }

    $zipUrl = "https://downloads.rclone.org/rclone-current-windows-$arch.zip"
    $zipPath = Join-Path $ToolsDir "rclone.zip"
    $extractDir = Join-Path $ToolsDir "rclone_extract"

    if (Test-Path $extractDir) {
        Remove-Item -Recurse -Force $extractDir
    }

    Write-Host "Downloading official rclone package..."
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    }
    catch {
        Write-Host "Invoke-WebRequest failed. Trying curl.exe..." -ForegroundColor Yellow
        & curl.exe -L --fail --retry 5 --retry-delay 3 -o $zipPath $zipUrl
        if ($LASTEXITCODE -ne 0) {
            throw "Could not download rclone."
        }
    }

    Write-Host "Extracting..."
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $found = Get-ChildItem -Path $extractDir -Filter "rclone.exe" -Recurse | Select-Object -First 1
    if (-not $found) {
        throw "rclone.exe was not found after extraction."
    }

    Copy-Item $found.FullName $RcloneExe -Force
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "rclone installed locally: $RcloneExe" -ForegroundColor Green
}

function Get-RemoteNames {
    # Config file is pre-created on startup. Keep native stderr suppressed here
    # so a harmless rclone notice cannot abort first-time setup.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $raw = & $RcloneExe --config $ConfigPath listremotes 2>$null
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($exitCode -ne 0 -or -not $raw) {
        return @()
    }

    return @($raw | ForEach-Object { $_.Trim().TrimEnd(":") } | Where-Object { $_ })
}

function Select-GDriveRemote {
    $remotes = @(Get-RemoteNames)
    if ($remotes.Count -eq 0) {
        Write-Host "No rclone remotes are configured yet." -ForegroundColor Yellow
        return $null
    }

    Write-Host ""
    Write-Host "Configured remotes:"
    for ($i = 0; $i -lt $remotes.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $remotes[$i])
    }

    $defaultIndex = 1
    $choice = Read-Host "Select remote [default $defaultIndex]"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return $remotes[0]
    }

    $n = 0
    if ([int]::TryParse($choice, [ref]$n) -and $n -ge 1 -and $n -le $remotes.Count) {
        return $remotes[$n - 1]
    }

    if ($remotes -contains $choice) {
        return $choice
    }

    Write-Host "Invalid remote selection." -ForegroundColor Red
    return $null
}


function Show-GoogleOAuthHelp {
    Write-Host ""
    Write-Host "================ GOOGLE OAUTH HELP ================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Open Google Cloud Console:"
    Write-Host "  https://console.cloud.google.com/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "STEP 1 - Create / select a project"
    Write-Host "  Google Cloud Console"
    Write-Host "    -> top project selector"
    Write-Host "    -> New Project (or select an existing project)"
    Write-Host ""
    Write-Host "STEP 2 - Enable Google Drive API"
    Write-Host "  Google Cloud Console"
    Write-Host "    -> APIs & Services"
    Write-Host "    -> Library"
    Write-Host "    -> search: Google Drive API"
    Write-Host "    -> Google Drive API"
    Write-Host "    -> Enable"
    Write-Host ""
    Write-Host "STEP 3 - Configure Google Auth Platform"
    Write-Host "  Google Cloud Console"
    Write-Host "    -> Google Auth Platform"
    Write-Host "    -> Branding"
    Write-Host "       Add App name + Support email + Developer contact email"
    Write-Host ""
    Write-Host "STEP 4 - Audience"
    Write-Host "  Google Auth Platform"
    Write-Host "    -> Audience"
    Write-Host "    -> External   (for normal Gmail / personal Google accounts)"
    Write-Host "    -> Test users"
    Write-Host "    -> Add the Google account that will use this tool"
    Write-Host ""
    Write-Host "STEP 5 - Create OAuth Client"
    Write-Host "  Google Auth Platform"
    Write-Host "    -> Clients"
    Write-Host "    -> Create Client"
    Write-Host "    -> Application type: Desktop app"
    Write-Host "    -> Name: Wihanga4U GDrive Uploader"
    Write-Host "    -> Create"
    Write-Host ""
    Write-Host "STEP 6 - Copy credentials"
    Write-Host "  Copy the:"
    Write-Host "    - Client ID      (usually ends with .apps.googleusercontent.com)"
    Write-Host "    - Client Secret"
    Write-Host ""
    Write-Host "SECURITY:" -ForegroundColor Yellow
    Write-Host "  Never upload your Client Secret or .data\rclone.conf to GitHub."
    Write-Host "  Do not share screenshots that show your Client Secret."
    Write-Host ""
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Read-OAuthClientId {
    while ($true) {
        Write-Host ""
        Write-Host "Need help getting the Client ID?" -ForegroundColor Cyan
        Write-Host "Type H and press ENTER to show the full Google Cloud path."
        $clientId = Read-Host "Google OAuth Client ID [H = Help]"

        if ($clientId -match "^(h|help|\?)$") {
            Show-GoogleOAuthHelp
            continue
        }

        if ([string]::IsNullOrWhiteSpace($clientId)) {
            Write-Host "Client ID is required. Type H for help." -ForegroundColor Red
            continue
        }

        return $clientId.Trim()
    }
}

function Read-OAuthClientSecret {
    while ($true) {
        Write-Host ""
        Write-Host "If you need the Client Secret path, type H at the next prompt." -ForegroundColor Cyan
        $plainChoice = Read-Host "Press ENTER to enter Client Secret securely, or type H for Help"

        if ($plainChoice -match "^(h|help|\?)$") {
            Show-GoogleOAuthHelp
            continue
        }

        $secureSecret = Read-Host "Google OAuth Client Secret (hidden)" -AsSecureString
        $clientSecret = [System.Net.NetworkCredential]::new("", $secureSecret).Password

        if ([string]::IsNullOrWhiteSpace($clientSecret)) {
            Write-Host "Client Secret is required. Type H for help." -ForegroundColor Red
            continue
        }

        return $clientSecret
    }
}

function Setup-GoogleDrive {
    Write-Title "Google Drive first-time setup"

    Write-Host "Before continuing, create your own Google OAuth Desktop App."
    Write-Host "You need:"
    Write-Host "  1. OAuth Client ID"
    Write-Host "  2. OAuth Client Secret"
    Write-Host ""
    Write-Host "Do NOT publish your Client Secret or .data\rclone.conf on GitHub." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Tip: When Client ID / Client Secret is requested, type H for a step-by-step Google Cloud guide." -ForegroundColor Cyan
    Write-Host ""

    $remoteName = Read-Host "Remote name [gdrive] (press ENTER to use gdrive)"
    if ([string]::IsNullOrWhiteSpace($remoteName)) {
        $remoteName = "gdrive"
    }

    if ((Get-RemoteNames) -contains $remoteName) {
        $replace = Read-Host "Remote '$remoteName' already exists. Replace its config? [y/N]"
        if ($replace -notmatch "^(y|yes)$") {
            Write-Host "Setup cancelled."
            return
        }
        & $RcloneExe --config $ConfigPath config delete $remoteName | Out-Null
    }

    $clientId = Read-OAuthClientId
    $clientSecret = Read-OAuthClientSecret

    Write-Host ""
    Write-Host "Your browser should open for Google authorization." -ForegroundColor Cyan
    Write-Host "Log in to the Google Drive account you want to use and allow access."
    Write-Host ""

    & $RcloneExe --config $ConfigPath config create $remoteName drive `
        "client_id=$clientId" `
        "client_secret=$clientSecret" `
        "scope=drive" `
        "config_is_local=true"

    $exitCode = $LASTEXITCODE
    $clientSecret = $null
    $secureSecret = $null

    if ($exitCode -ne 0) {
        Write-Host "Google Drive setup failed." -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "Testing Google Drive connection..." -ForegroundColor Cyan
    & $RcloneExe --config $ConfigPath lsd "${remoteName}:" --max-depth 1

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Google Drive connected successfully." -ForegroundColor Green
    }
    else {
        Write-Host "Remote was created, but the connection test failed." -ForegroundColor Yellow
    }
}

function Normalize-DriveFolder([string]$Folder) {
    if ([string]::IsNullOrWhiteSpace($Folder)) {
        return "Downloads"
    }
    $f = $Folder.Trim().Replace("\", "/").Trim("/")
    if ([string]::IsNullOrWhiteSpace($f)) {
        return "Downloads"
    }
    return $f
}

function Upload-UrlToDrive {
    Write-Title "Direct URL -> Google Drive"

    $remote = Select-GDriveRemote
    if (-not $remote) {
        Write-Host "Run option 1 first." -ForegroundColor Yellow
        return
    }

    $url = Read-Host "Paste the DIRECT download URL"
    if ($url -notmatch "^https?://") {
        Write-Host "A valid http/https direct URL is required." -ForegroundColor Red
        return
    }

    $folder = Normalize-DriveFolder (Read-Host "Google Drive folder [Downloads]")
    $fileName = Read-Host "Output file name [download.zip]"
    if ([string]::IsNullOrWhiteSpace($fileName)) {
        $fileName = "download.zip"
    }

    $target = "${remote}:$folder/$fileName"

    Write-Host ""
    Write-Host "Target: $target" -ForegroundColor Cyan
    Write-Host "The full file is streamed to Google Drive; it is not first saved to the local disk."
    Write-Host "If the source URL has an expiring token, a fresh URL may be required after expiry." -ForegroundColor Yellow
    Write-Host ""

    $go = Read-Host "Start upload now? [Y/n]"
    if ($go -match "^(n|no)$") {
        return
    }

    & $RcloneExe --config $ConfigPath copyurl $url $target `
        -P `
        --stats 5s `
        --retries 10 `
        --low-level-retries 20 `
        --retries-sleep 10s `
        --timeout 30m `
        --contimeout 60s `
        --drive-chunk-size 64M

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Upload did not complete successfully." -ForegroundColor Red
        Write-Host "You can retry with a fresh direct URL. Do not delete the source file."
        return
    }

    Write-Host ""
    Write-Host "Upload completed successfully." -ForegroundColor Green

    $split = Read-Host "Split the uploaded Drive file into parts now? [y/N]"
    if ($split -match "^(y|yes)$") {
        Split-DriveFile -RemoteName $remote -SourceFolder $folder -SourceFileName $fileName
    }
}

function Split-DriveFile {
    param(
        [string]$RemoteName = "",
        [string]$SourceFolder = "",
        [string]$SourceFileName = ""
    )

    Write-Title "Split an existing Google Drive file"

    if ([string]::IsNullOrWhiteSpace($RemoteName)) {
        $RemoteName = Select-GDriveRemote
        if (-not $RemoteName) {
            Write-Host "Run option 1 first." -ForegroundColor Yellow
            return
        }
    }

    if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
        $SourceFolder = Normalize-DriveFolder (Read-Host "Source Drive folder [Downloads]")
    }

    if ([string]::IsNullOrWhiteSpace($SourceFileName)) {
        $SourceFileName = Read-Host "Source file name (example: 160GB-download.zip)"
    }

    if ([string]::IsNullOrWhiteSpace($SourceFileName)) {
        Write-Host "Source file name is required." -ForegroundColor Red
        return
    }

    $chunkSizeInput = Read-Host "Part size in GiB [10]"
    if ([string]::IsNullOrWhiteSpace($chunkSizeInput)) {
        $chunkSizeInput = "10"
    }

    $chunkSize = 0
    if (-not [int]::TryParse($chunkSizeInput, [ref]$chunkSize) -or $chunkSize -lt 1) {
        Write-Host "Invalid part size." -ForegroundColor Red
        return
    }

    $defaultPartsFolder = "$SourceFolder/Parts${chunkSize}GB"
    $partsFolderInput = Read-Host "Parts folder [$defaultPartsFolder]"
    if ([string]::IsNullOrWhiteSpace($partsFolderInput)) {
        $partsFolder = $defaultPartsFolder
    }
    else {
        $partsFolder = Normalize-DriveFolder $partsFolderInput
    }

    $source = "${RemoteName}:$SourceFolder/$SourceFileName"
    $underlyingParts = "${RemoteName}:$partsFolder"
    $chunkRemote = "parts${chunkSize}gb"

    Write-Host ""
    Write-Host "Source (kept unchanged): $source" -ForegroundColor Cyan
    Write-Host "Parts folder:            $underlyingParts" -ForegroundColor Cyan
    Write-Host "Part size:               ${chunkSize} GiB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The original Drive file is READ only and is not deleted or modified." -ForegroundColor Green
    Write-Host "During transfer, temporary chunk names with an extra random suffix can appear. That is normal." -ForegroundColor Yellow
    Write-Host ""

    $go = Read-Host "Start splitting? [Y/n]"
    if ($go -match "^(n|no)$") {
        return
    }

    # Verify source exists
    & $RcloneExe --config $ConfigPath lsjson $source --stat | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Source file was not found or cannot be read." -ForegroundColor Red
        return
    }

    & $RcloneExe --config $ConfigPath mkdir $underlyingParts
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Could not create/access the parts folder." -ForegroundColor Red
        return
    }

    # Recreate only the local rclone chunker configuration.
    # This does NOT delete any Google Drive files.
    if ((Get-RemoteNames) -contains $chunkRemote) {
        & $RcloneExe --config $ConfigPath config delete $chunkRemote | Out-Null
    }

    & $RcloneExe --config $ConfigPath config create $chunkRemote chunker `
        "remote=$underlyingParts" `
        "chunk_size=${chunkSize}G" `
        "hash_type=none" `
        "meta_format=none" `
        "name_format=*.###"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Could not create the chunker configuration." -ForegroundColor Red
        return
    }

    & $RcloneExe --config $ConfigPath copyto $source "${chunkRemote}:$SourceFileName" `
        -P `
        --stats 5s `
        --retries 10 `
        --low-level-retries 20 `
        --retries-sleep 10s `
        --timeout 30m `
        --contimeout 60s `
        --drive-chunk-size 64M

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Splitting completed successfully." -ForegroundColor Green
        Write-Host "Physical part files are in: $underlyingParts"
        Write-Host ""
        & $RcloneExe --config $ConfigPath ls $underlyingParts
    }
    else {
        Write-Host ""
        Write-Host "Splitting did not complete successfully." -ForegroundColor Red
        Write-Host "The ORIGINAL source file is still unchanged."
        Write-Host "Incomplete temporary chunk files may remain in the parts folder and consume Drive storage." -ForegroundColor Yellow
    }
}

function List-DriveFolder {
    Write-Title "List Google Drive folder"

    $remote = Select-GDriveRemote
    if (-not $remote) {
        return
    }

    $folderRaw = Read-Host "Drive folder [Downloads]"
    $folder = Normalize-DriveFolder $folderRaw

    & $RcloneExe --config $ConfigPath lsl "${remote}:$folder"
}

function Show-SecurityInfo {
    Write-Title "Wihanga4U - Security / GitHub safety"
    Write-Host "Safe to commit:"
    Write-Host "  START.bat"
    Write-Host "  GDriveUploader.ps1"
    Write-Host "  JoinParts.ps1 / JOIN_PARTS.bat"
    Write-Host "  README.md"
    Write-Host ""
    Write-Host "NEVER commit:"
    Write-Host "  .data\rclone.conf" -ForegroundColor Yellow
    Write-Host "  OAuth Client Secret" -ForegroundColor Yellow
    Write-Host "  Direct URLs containing private/temporary tokens" -ForegroundColor Yellow
    Write-Host ""
    Write-Host ".gitignore in this package already excludes .data and .tools."
}

function Main-Menu {
    while ($true) {
        Clear-Host
        Write-Title "Wihanga4U GDrive Direct Uploader"
        Write-Host "Developed by Wihanga4U" -ForegroundColor Green
        Write-Host "GitHub: https://github.com/wihanga4uu"
        Write-Host ""
        Write-Host "No Node.js or npm is required."
        Write-Host "rclone is downloaded automatically on first run."
        Write-Host ""
        Write-Host "  [1] First-time Google Drive setup (Client ID Help included)"
        Write-Host "  [2] Direct URL -> Google Drive"
        Write-Host "  [3] Split existing Drive file into parts"
        Write-Host "  [4] List Drive folder"
        Write-Host "  [5] Security / GitHub info"
        Write-Host "  [0] Exit"
        Write-Host ""

        $choice = Read-Host "Choose an option"

        switch ($choice) {
            "1" { Setup-GoogleDrive; Pause-App }
            "2" { Upload-UrlToDrive; Pause-App }
            "3" { Split-DriveFile; Pause-App }
            "4" { List-DriveFolder; Pause-App }
            "5" { Show-SecurityInfo; Pause-App }
            "0" { return }
            default {
                Write-Host "Invalid option." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

try {
    Ensure-Rclone
    Main-Menu
}
catch {
    Write-Host ""
    Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host ""
    exit 1
}
