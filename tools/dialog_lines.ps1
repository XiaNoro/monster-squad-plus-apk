# Collapses per-frame OCR of the dialogue-box crop (tools/ocr_frames.ps1 on 2 fps crops) into the
# distinct dialogue lines, with the video time each first appeared.
# Usage: powershell -File tools/dialog_lines.ps1 <frames folder> [-Fps 2]
param([string]$Dir, [double]$Fps = 2)

function Norm([string]$s) { ($s.ToLower() -replace '[^a-z0-9]', '') }

# Similarity: shared characters in order (cheap LCS ratio on normalised text).
function Similar([string]$a, [string]$b) {
    if ($a.Length -eq 0 -or $b.Length -eq 0) { return 0.0 }
    if ($a.Contains($b) -or $b.Contains($a)) { return 1.0 }
    $n = [Math]::Min($a.Length, 120); $m = [Math]::Min($b.Length, 120)
    $prev = New-Object int[] ($m + 1)
    for ($i = 1; $i -le $n; $i++) {
        $cur = New-Object int[] ($m + 1)
        for ($j = 1; $j -le $m; $j++) {
            if ($a[$i - 1] -eq $b[$j - 1]) { $cur[$j] = $prev[$j - 1] + 1 } else { $cur[$j] = [Math]::Max($prev[$j], $cur[$j - 1]) }
        }
        $prev = $cur
    }
    return 2.0 * $prev[$m] / ($n + $m)
}

$speakers = 'Firepaw|Mini|Emberpeep|Rookie|Leavbal|Dripbal|Pufbal|Spooki|Stumpy|Belle|Sapphibi|Twirly|Ibi|Narkissa'
$out = @()
$last = ''
$lastBest = ''
foreach ($row in Get-Content (Join-Path $Dir 'ocr.tsv') -Encoding UTF8) {
    $parts = $row.Split("`t")
    if ($parts.Count -lt 2) { continue }
    $frame = [int]($parts[0] -replace '\D', '')
    $lines = $parts[1].Split('|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    # The speaker line, then the sentence lines after it.
    $idx = -1
    for ($k = 0; $k -lt $lines.Count; $k++) { if ($lines[$k] -match "^($speakers)$") { $idx = $k; break } }
    if ($idx -lt 0) { $last = ''; continue }
    $who = $lines[$idx]
    $text = (($lines[($idx + 1)..($lines.Count - 1)] | Where-Object { $_.Length -gt 3 -and $_ -match '[a-z]{2}' }) -join ' ').Trim()
    if ($text.Length -lt 6) { continue }
    $key = Norm "$who $text"
    if ((Similar $key $last) -gt 0.8) {
        # Same line still showing: keep the longest (most complete) reading.
        if ($text.Length -gt $out[-1].text.Length) { $out[-1].text = $text }
        $last = $key
        continue
    }
    $t = ($frame - 1) / $Fps
    $out += [pscustomobject]@{ time = ('{0:00}:{1:00}' -f [Math]::Floor($t / 60), ($t % 60)); who = $who; text = $text }
    $last = $key
}
$out | ForEach-Object { "[$($_.time)] $($_.who): $($_.text)" }
