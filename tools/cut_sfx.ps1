# Cuts a sound from a downloaded video and peak-normalizes it.
# Usage: powershell -File tools/cut_sfx.ps1 <video id> <start sec> <length sec> <name> [-Peak -1.5] [-Fade 0.15]
param([string]$Id, [double]$Start, [double]$Length, [string]$Name, [double]$Peak = -1.5, [double]$Fade = 0.15)
$v = Get-ChildItem research/videos/video_hd, research/videos/video -Filter "*$Id.mp4" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $v) { Write-Error "no video $Id"; exit 1 }
$m = & research/bin/ffmpeg.exe -hide_banner -ss $Start -t $Length -i $v.FullName -vn -af volumedetect -f null NUL 2>&1 | Select-String 'max_volume: (-?[\d\.]+)'
$gain = $Peak - [double]$m.Matches[0].Groups[1].Value
$fo = [math]::Max(0, $Length - $Fade)
& research/bin/ffmpeg.exe -loglevel error -y -ss $Start -t $Length -i $v.FullName -vn -ac 2 -ar 44100 -af "volume=${gain}dB,afade=t=in:d=0.01,afade=t=out:st=${fo}:d=$Fade" -c:a libvorbis -q:a 6 "assets/sfx/$Name.ogg"
"{0}: {1} +{2:N1} dB" -f $Name, $v.Name, $gain
