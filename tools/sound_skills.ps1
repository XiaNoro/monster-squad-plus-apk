# Reads the skill name shown on screen at each confident sound hit (from tools/match_sounds.py) and tallies sound -> skill votes.
# Usage: powershell -File tools/sound_skills.ps1 <hits.tsv> <out.tsv> [-MinScore 0.7] [-PerSound 14]
param([string]$Hits, [string]$Out, [double]$MinScore = 0.7, [int]$PerSound = 14)
$root = Split-Path $PSScriptRoot
$ff = "$root/research/bin/ffmpeg.exe"
$dir = "$root/research/videos/sound_ocr"
New-Item -ItemType Directory -Force $dir | Out-Null
Get-ChildItem $dir -File | Remove-Item
$vid = @{}
Get-ChildItem "$root/research/videos" -Recurse -Filter *.mp4 | ForEach-Object { if (-not $vid.ContainsKey($_.Name)) { $vid[$_.Name] = $_.FullName } }
$rows = Import-Csv $Hits -Delimiter "`t" -Header v, t, s, score | Where-Object { [double]$_.score -ge $MinScore -and $_.s -match '_(cast|damage|cast_voice)\.ogg$' }
$n = 0
foreach ($g in $rows | Group-Object s) {
	$pick = $g.Group | Sort-Object { [double]$_.score } -Descending | Group-Object v | ForEach-Object { $_.Group | Select-Object -First 4 } | Sort-Object { [double]$_.score } -Descending | Select-Object -First $PerSound
	foreach ($p in $pick) {
		foreach ($dt in 0.3, 0.9) {
			$name = "{0:D5}~{1}~{2}~{3}.png" -f $n, $g.Name.Replace('.ogg', ''), $p.v.Replace('.mp4', ''), $dt
			& $ff -v error -y -ss ([double]$p.t + $dt) -i $vid[$p.v] -frames:v 1 -vf "crop=iw*0.62:ih*0.34:iw*0.08:ih*0.5,scale=-1:720" "$dir/$name"
			$n++
		}
	}
}
& powershell -NoProfile -File "$PSScriptRoot/ocr_frames.ps1" $dir | Out-Host
$skills = @{}
$db = Get-Content "$root/data/monsters.json" -Raw | ConvertFrom-Json
foreach ($m in $db.PSObject.Properties.Value) {
	foreach ($s in @($m.skills) + @($m.support_skill)) {
		if ($s -and $s.name -and $s.name.Length -ge 4) { $skills[$s.name.ToLower()] = $s.name }
	}
}
$names = $skills.Keys | Sort-Object Length -Descending
$votes = @{}
foreach ($line in Get-Content "$dir/ocr.tsv") {
	$f, $text = $line -split "`t", 2
	$sound = ($f -split '~')[1]
	$t = " " + ($text.ToLower() -replace '[^a-z0-9'' ]', ' ' -replace '\s+', ' ') + " "
	foreach ($k in $names) {
		if ($t.Contains(" $k ")) {
			$key = "$sound`t$($skills[$k])"
			$votes[$key] = 1 + [int]$votes[$key]
			break
		}
	}
}
$votes.GetEnumerator() | Sort-Object { $_.Key.Split("`t")[0] }, { - $_.Value } | ForEach-Object { "$($_.Key)`t$($_.Value)" } | Set-Content $Out -Encoding utf8
"votes: $($votes.Count) -> $Out"
