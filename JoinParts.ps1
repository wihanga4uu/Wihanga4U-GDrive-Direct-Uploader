$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Join Downloaded Parts" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Use this AFTER all .001, .002, .003 ... parts are downloaded"
Write-Host "to the same folder on your normal PC."
Write-Host ""

$folder = Read-Host "Folder containing the parts"
if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path $folder)) {
    throw "Folder not found."
}

$baseName = Read-Host "Original file name (example: 160GB-download.zip)"
if ([string]::IsNullOrWhiteSpace($baseName)) {
    throw "File name is required."
}

$pattern = [regex]::Escape($baseName) + "\.(\d{3,})$"
$parts = Get-ChildItem -Path $folder -File | Where-Object {
    $_.Name -match $pattern
} | Sort-Object {
    [int]([regex]::Match($_.Name, "\.(\d{3,})$").Groups[1].Value)
}

if (-not $parts -or $parts.Count -eq 0) {
    throw "No matching .001/.002/... parts were found."
}

# Check numbering is continuous.
for ($i = 0; $i -lt $parts.Count; $i++) {
    $expected = $i + 1
    $actual = [int]([regex]::Match($parts[$i].Name, "\.(\d{3,})$").Groups[1].Value)
    if ($actual -ne $expected) {
        throw "Part numbering is incomplete. Expected part $expected but found part $actual."
    }
}

$outPath = Join-Path $folder $baseName
if (Test-Path $outPath) {
    $answer = Read-Host "Output file already exists: $outPath . Overwrite? [y/N]"
    if ($answer -notmatch "^(y|yes)$") {
        Write-Host "Cancelled."
        exit 0
    }
    Remove-Item $outPath -Force
}

$totalBytes = ($parts | Measure-Object Length -Sum).Sum
Write-Host ""
Write-Host ("Parts found: {0}" -f $parts.Count)
Write-Host ("Combined size: {0:N2} GiB" -f ($totalBytes / 1GB))
Write-Host ("Output: {0}" -f $outPath)
Write-Host ""
Write-Host "Make sure the destination drive has enough free space for the combined file." -ForegroundColor Yellow
$go = Read-Host "Start joining? [Y/n]"
if ($go -match "^(n|no)$") {
    exit 0
}

$buffer = New-Object byte[] (8MB)
$outStream = [System.IO.File]::Open($outPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

try {
    $done = [int64]0
    foreach ($part in $parts) {
        Write-Host ("Joining {0}..." -f $part.Name)
        $inStream = [System.IO.File]::OpenRead($part.FullName)
        try {
            while (($read = $inStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $outStream.Write($buffer, 0, $read)
                $done += $read
            }
        }
        finally {
            $inStream.Dispose()
        }

        $pct = if ($totalBytes -gt 0) { [math]::Round(($done / $totalBytes) * 100, 1) } else { 100 }
        Write-Host ("Progress: {0}%" -f $pct)
    }
}
finally {
    $outStream.Dispose()
}

$finalSize = (Get-Item $outPath).Length
if ($finalSize -ne $totalBytes) {
    throw "Joined file size verification failed."
}

Write-Host ""
Write-Host "JOIN COMPLETE" -ForegroundColor Green
Write-Host $outPath
Write-Host ""
Write-Host "Open/test the joined file before deleting the .001/.002/... parts."
