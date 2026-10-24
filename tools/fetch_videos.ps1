# Downloads every video in research/videos/wanted.tsv at up to 1080p (plus info.json and English captions)
# into research/videos/video_hd, and extracts a frame every 2 s into research/videos/frames_hd/<id>/<sec>.jpg.
# Already-downloaded videos are skipped. Log: research/videos/video_hd/fetch.log
# Usage: powershell -File tools/fetch_videos.ps1 [-cookies <youtube.com cookies.txt>]
# When YouTube asks to "confirm you're not a bot", pass a cookies.txt exported from youtube.com.
# research/bin/deno.exe solves YouTube's stream-URL challenge.
param([string]$cookies = "")
$root = "research/videos"
$auth = @("--js-runtimes", "deno:research/bin/deno.exe", "--remote-components", "ejs:github")
if ($cookies -ne "") { $auth += @("--cookies", $cookies) }
$out = "$root/video_hd"
$frames = "$root/frames_hd"
New-Item -ItemType Directory -Force $out, $frames | Out-Null
$log = "$out/fetch.log"
$rows = Import-Csv "$root/wanted.tsv" -Delimiter "`t"
foreach ($r in $rows) {
    $id = $r.id
    $mp4 = Get-ChildItem $out -Filter "$id.mp4" -ErrorAction SilentlyContinue
    if (-not $mp4) {
        & research/bin/yt-dlp.exe -q --no-warnings --ffmpeg-location research/bin @auth `
            -f "bv*[height<=1080]+ba/b" --merge-output-format mp4 `
            --write-info-json --write-auto-subs --sub-langs "en.*" --convert-subs vtt `
            -o "$out/%(id)s.%(ext)s" "https://www.youtube.com/watch?v=$id"
        $mp4 = Get-ChildItem $out -Filter "$id.mp4" -ErrorAction SilentlyContinue
        if (-not $mp4) {
            & research/bin/yt-dlp.exe -q --no-warnings --ffmpeg-location research/bin @auth -f "bv*+ba/b" --merge-output-format mp4 `
                --write-info-json -o "$out/%(id)s.%(ext)s" "https://www.youtube.com/watch?v=$id"
            $mp4 = Get-ChildItem $out -Filter "$id.mp4" -ErrorAction SilentlyContinue
        }
    }
    if (-not $mp4) { Add-Content $log "FAIL $id"; continue }
    $fd = "$frames/$id"
    if (-not (Test-Path $fd) -or -not (Get-ChildItem $fd -Filter *.jpg)) {
        New-Item -ItemType Directory -Force $fd | Out-Null
        & research/bin/ffmpeg.exe -y -loglevel error -i $mp4.FullName -vf "fps=1/2" -q:v 3 "$fd/f%05d.jpg"
        Get-ChildItem $fd -Filter f*.jpg | ForEach-Object {
            $n = [int]$_.BaseName.Substring(1)
            Rename-Item $_.FullName ("{0:D4}.jpg" -f (($n - 1) * 2)) -Force
        }
    }
    $h = & research/bin/ffmpeg.exe -i $mp4.FullName 2>&1 | Select-String -Pattern "Video:.* (\d{3,4})x(\d{3,4})" | Select-Object -First 1
    $res = if ($h) { "$($h.Matches[0].Groups[1].Value)x$($h.Matches[0].Groups[2].Value)" } else { "?" }
    Add-Content $log ("OK {0} {1} {2:N0}MB {3}" -f $id, $res, ($mp4.Length / 1MB), $r.purpose)
}
Add-Content $log "DONE"
