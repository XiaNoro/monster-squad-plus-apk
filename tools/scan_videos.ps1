# Extracts one frame every N seconds from each downloaded video, then OCRs them.
# Output: research/videos/frames/<video>/<seconds>.jpg and ocr.tsv; skips videos already scanned.
# Usage: powershell -File tools/scan_videos.ps1 [-Every 2]
param([int]$Every = 2, [string]$VideoDir = 'video', [string]$FramesDir = 'frames')

$root = Split-Path $PSScriptRoot -Parent
$bin = Join-Path $root 'research\bin'
$videos = Join-Path $root ('research\videos\' + $VideoDir)
$framesRoot = Join-Path $root ('research\videos\' + $FramesDir)

foreach ($v in Get-ChildItem $videos -Filter *.mp4 | Sort-Object Name) {
    $dir = Join-Path $framesRoot $v.BaseName
    if (Test-Path (Join-Path $dir 'ocr.tsv')) { continue }
    New-Item -ItemType Directory -Force $dir | Out-Null
    & (Join-Path $bin 'ffmpeg.exe') -loglevel error -y -i $v.FullName -vf "fps=1/$Every,scale=854:-2" -q:v 4 (Join-Path $dir 'f%05d.jpg')
    # Rename sequence numbers to timestamps (seconds) so findings can cite video times.
    foreach ($f in Get-ChildItem $dir -Filter 'f*.jpg') {
        $n = [int]$f.BaseName.Substring(1)
        Rename-Item $f.FullName ('{0:D5}.jpg' -f (($n - 1) * $Every))
    }
    & powershell -NoProfile -File (Join-Path $PSScriptRoot 'ocr_frames.ps1') $dir | Out-Null
    "scanned $($v.BaseName): $((Get-ChildItem $dir -Filter *.jpg).Count) frames"
}
