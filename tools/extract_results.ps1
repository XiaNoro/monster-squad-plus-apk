# Pulls quest results out of the OCR'd walkthrough frames.
# For each "Quest Successful!" screen it records the most recent stage name seen (e.g. "Lake-7"),
# the difficulty if shown, clear time, FP and gold. Output: research/videos/quest_results.tsv
param()

$root = Split-Path $PSScriptRoot -Parent
$framesRoot = Join-Path $root 'research\videos\frames'
$islands = 'Sprout|Lake|Desert|Moonlight|Boneyard|Dino|Robo|Sky|Material|Spirit|Friendship|Mansion|Icicle|Volcano|Training|Treasure|Magic|Elemental|Candy|Deep Ocean'
$stageRx = "(?i)\b($islands)\s?-\s?(\d{1,2})\b"
$rows = New-Object System.Collections.Generic.List[string]
$rows.Add("video`tframe_s`tstage`tdifficulty`tclear`tfp`tgold`tcubes")

foreach ($dir in Get-ChildItem $framesRoot -Directory | Sort-Object Name) {
    $ocr = Join-Path $dir.FullName 'ocr.tsv'
    if (-not (Test-Path $ocr)) { continue }
    $stage = ''
    $diff = ''
    $lastKey = ''
    foreach ($line in Get-Content $ocr -Encoding utf8) {
        $parts = $line -split "`t", 2
        if ($parts.Count -lt 2) { continue }
        $t = [int]($parts[0] -replace '\D', '')
        $text = $parts[1]
        $m = [regex]::Match($text, $stageRx)
        if ($m.Success -and $text -notmatch 'Quest Success') {
            $stage = (Get-Culture).TextInfo.ToTitleCase($m.Groups[1].Value.ToLower()) + '-' + $m.Groups[2].Value
        }
        $d = [regex]::Match($text, '(?i)\b(Normal|Hard|Hell)\b')
        if ($d.Success -and $text -match '(?i)select friend|go\b|energy') { $diff = $d.Groups[1].Value }
        if ($text -notmatch '(?i)quest success') { continue }
        $clear = ([regex]::Match($text, '\b(\d{2})\s?:\s?(\d{2})\b')).Value -replace '\s', ''
        $fp = ([regex]::Match($text, '\+(\d{2})\b')).Groups[1].Value
        # Gold is the first 3-6 digit number after the FP field.
        $after = if ($fp) { $text.Substring($text.IndexOf("+$fp") + 3) } else { $text }
        $gold = ([regex]::Match($after, '\b(\d{1,3}(?:,\d{3})+|\d{3,6})\b')).Groups[1].Value -replace ',', ''
        $cubes = if ($text -match '(?i)no cubes') { 'none' } elseif ($text -match '(?i)open cube') { 'cube' } else { '' }
        $key = "$stage|$clear|$gold"
        if ($key -eq $lastKey -or -not $gold) { continue }
        $lastKey = $key
        $rows.Add("$($dir.Name)`t$t`t$stage`t$diff`t$clear`t$fp`t$gold`t$cubes")
    }
}
$out = Join-Path $root 'research\videos\quest_results.tsv'
Set-Content $out $rows -Encoding utf8
"results: $($rows.Count - 1) -> $out"
