# Re-reads "Quest Successful!" frames at higher accuracy: crops the result panel and the
# "Stage x/y" label, upscales 2x, and OCRs them. Output: research/videos/quest_results_precise.tsv
param()

Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$framesRoot = Join-Path $root 'research\videos\frames'
$tmp = Join-Path $env:TEMP 'ms_ocr_crops'
if (Test-Path $tmp) { Get-ChildItem $tmp -File | Remove-Item -Force }
New-Item -ItemType Directory -Force $tmp | Out-Null

# Pass 1: crop panels of every result frame (frames are 854x480).
$index = @{}
$islands = 'Sprout|Lake|Desert|Moonlight|Boneyard|Dino|Robo|Sky|Material|Spirit|Friendship|Mansion|Icicle|Volcano|Training|Treasure|Magic|Elemental|Candy'
foreach ($dir in Get-ChildItem $framesRoot -Directory | Sort-Object Name) {
    $ocr = Join-Path $dir.FullName 'ocr.tsv'
    if (-not (Test-Path $ocr)) { continue }
    $stage = ''
    foreach ($line in Get-Content $ocr -Encoding utf8) {
        $parts = $line -split "`t", 2
        if ($parts.Count -lt 2) { continue }
        $m = [regex]::Match($parts[1], "(?i)\b($islands)\s?-\s?(\d{1,2})\b")
        if ($m.Success -and $parts[1] -notmatch 'Quest Success') {
            $stage = (Get-Culture).TextInfo.ToTitleCase($m.Groups[1].Value.ToLower()) + '-' + $m.Groups[2].Value
        }
        if ($parts[1] -notmatch '(?i)quest success') { continue }
        $src = Join-Path $dir.FullName $parts[0]
        $img = [System.Drawing.Image]::FromFile($src)
        foreach ($crop in @(@('panel', 200, 150, 454, 150), @('top', 300, 20, 254, 70))) {
            $bmp = New-Object System.Drawing.Bitmap ($crop[3] * 2), ($crop[4] * 2)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, ($crop[3] * 2), ($crop[4] * 2)), (New-Object System.Drawing.Rectangle $crop[1], $crop[2], $crop[3], $crop[4]), [System.Drawing.GraphicsUnit]::Pixel)
            $name = "$($dir.Name)__$($parts[0] -replace '\.jpg$','')__$($crop[0]).png"
            $bmp.Save((Join-Path $tmp $name), [System.Drawing.Imaging.ImageFormat]::Png)
            $g.Dispose(); $bmp.Dispose()
        }
        $img.Dispose()
        $index["$($dir.Name)__$($parts[0] -replace '\.jpg$','')"] = $stage
    }
}

# Pass 2: OCR the crops.
& powershell -NoProfile -File (Join-Path $PSScriptRoot 'ocr_frames.ps1') $tmp | Out-Null
$text = @{}
foreach ($line in Get-Content (Join-Path $tmp 'ocr.tsv') -Encoding utf8) {
    $p = $line -split "`t", 2
    $text[$p[0] -replace '\.png$', ''] = if ($p.Count -gt 1) { $p[1] } else { '' }
}

# Pass 3: parse. Panel shows [time-or-EXP] [+FP] [gold]; the top shows "Stage x/y" and the timer.
$rows = New-Object System.Collections.Generic.List[string]
$rows.Add("video`tframe_s`tstage`tstages_total`tclear`texp`tfp`tgold`tfirst_clear_gems")
$seen = @{}
foreach ($key in $index.Keys | Sort-Object) {
    $panel = $text["${key}__panel"]
    $top = $text["${key}__top"]
    $video, $frame = $key -split '__'
    $clear = ([regex]::Match("$top $panel", '\b(\d{2})\s?:\s?(\d{2})\b')).Value -replace '\s', ''
    $total = ([regex]::Match($top, '(?i)stage\s*\d\s*/\s*(\d)')).Groups[1].Value
    $exp = ([regex]::Match($panel, '(?i)EXP\D{0,6}(\d{2,4})')).Groups[1].Value
    $fp = ([regex]::Match($panel, '\+\s?(\d{2})')).Groups[1].Value
    $nums = [regex]::Matches($panel, '\b\d{1,3}(?:[,.]\d{3})+\b|\b\d{3,6}\b') | ForEach-Object { [int]($_.Value -replace '[,.]', '') }
    $gold = ($nums | Where-Object { $_ -ne [int]$exp } | Measure-Object -Maximum).Maximum
    $gems = ([regex]::Match($panel, '(?i)x\s?(\d{1,3})\b')).Groups[1].Value
    $dedupe = "$video|$($index[$key])|$gold"
    if (-not $gold -or $seen.ContainsKey($dedupe)) { continue }
    $seen[$dedupe] = $true
    $rows.Add("$video`t$([int]$frame)`t$($index[$key])`t$total`t$clear`t$exp`t$fp`t$gold`t$gems")
}
$out = Join-Path $root 'research\videos\quest_results_precise.tsv'
Set-Content $out $rows -Encoding utf8
"results: $($rows.Count - 1) -> $out"
