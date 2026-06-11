<#
  Swap the hero scroll-video.

  Usage:
      pwsh tool/prep_video.ps1 "C:\path\to\new-clip.mp4"

  Re-encodes the clip "all-intra" (every frame a keyframe) so it scrubs
  smoothly as you scroll, then writes it to web/media/scene.mp4 and refreshes
  the poster frame. No code changes are needed afterwards: the app reads the
  clip's duration and shape from the new file at runtime.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Source,
  [int]$Crf = 20
)

$ErrorActionPreference = "Stop"

# Resolve ffmpeg: prefer PATH, otherwise fall back to the winget install dir.
$ffmpeg = "ffmpeg"
try {
  Get-Command ffmpeg -ErrorAction Stop | Out-Null
} catch {
  $cand = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" `
    -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($cand) {
    $ffmpeg = $cand.FullName
  } else {
    throw "ffmpeg not found. Install it with: winget install Gyan.FFmpeg"
  }
}

if (-not (Test-Path $Source)) { throw "Input video not found: $Source" }

$root  = Split-Path -Parent $PSScriptRoot   # project root (tool/ sits under it)
$media = Join-Path $root "web\media"
New-Item -ItemType Directory -Force -Path $media | Out-Null

$scene  = Join-Path $media "scene.mp4"
$poster = Join-Path $media "poster.jpg"

Write-Host "Encoding (all-intra, crf $Crf):"
Write-Host "  $Source"
Write-Host "  -> $scene"
& $ffmpeg -y -hide_banner -loglevel error -i $Source -an -c:v libx264 `
  -preset slow -crf $Crf -g 1 -keyint_min 1 -sc_threshold 0 `
  -movflags +faststart -pix_fmt yuv420p $scene
& $ffmpeg -y -hide_banner -loglevel error -i $Source -vframes 1 -q:v 3 $poster

$mb = [math]::Round((Get-Item $scene).Length / 1MB, 2)
Write-Host ""
Write-Host "Done. scene.mp4 = $mb MB. Swap complete - no code changes needed."
