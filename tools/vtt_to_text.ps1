# Converts YouTube .vtt captions into readable transcripts with [mm:ss] markers every ~15s.
# Auto-captions repeat each line as it scrolls; this keeps only new words.
# Usage: powershell -File tools/vtt_to_text.ps1 research/videos/subs research/videos/transcripts
param([string]$SubsDir, [string]$OutDir)

New-Item -ItemType Directory -Force $OutDir | Out-Null
$groups = Get-ChildItem $SubsDir -Filter *.vtt | Group-Object { $_.Name.Split('.')[0] }
foreach ($g in $groups) {
    # Prefer human captions (en) over auto (en-orig) when both exist.
    $file = $g.Group | Sort-Object { if ($_.Name -match '\.en\.vtt$') { 0 } else { 1 } } | Select-Object -First 1
    $info = Join-Path $SubsDir "$($g.Name).info.json"
    $title = $g.Name
    if (Test-Path $info) { $title = (Get-Content $info -Raw | ConvertFrom-Json).title }

    $out = New-Object System.Text.StringBuilder
    [void]$out.AppendLine("# $title")
    [void]$out.AppendLine("# https://www.youtube.com/watch?v=$($g.Name)")
    $last = ""
    $lastMark = -999
    $time = 0
    foreach ($line in Get-Content $file.FullName -Encoding utf8) {
        if ($line -match '^(\d+):(\d+):(\d+)\.\d+ -->') {
            $time = [int]$Matches[1] * 3600 + [int]$Matches[2] * 60 + [int]$Matches[3]
            continue
        }
        if ($line -match '^(WEBVTT|Kind:|Language:|NOTE)' -or $line.Trim() -eq '') { continue }
        $text = ($line -replace '<[^>]+>', '').Trim()
        if ($text -eq '' -or $text -eq $last) { continue }
        # Rolling captions: drop the part already emitted.
        if ($last -ne '' -and $text.StartsWith($last)) { $text = $text.Substring($last.Length).Trim() }
        $last = ($line -replace '<[^>]+>', '').Trim()
        if ($text -eq '') { continue }
        if ($time - $lastMark -ge 15) {
            [void]$out.Append(("`n[{0:D2}:{1:D2}] " -f [int][math]::Floor($time / 60), ($time % 60)))
            $lastMark = $time
        }
        [void]$out.Append($text + ' ')
    }
    Set-Content (Join-Path $OutDir "$($g.Name).txt") $out.ToString() -Encoding utf8
}
"transcripts: $($groups.Count)"
