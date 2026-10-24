# Downloads the wiki's in-game monster icons ("<Name> Icon.png", 92x92, the game's own icon art) to
# assets/icons/<id>.png|webp and the island pictures to assets/islands/<id>.png|webp.
# Needs research/wiki/all_images.json (list=allimages dump). Skips files already present.
$root = Split-Path $PSScriptRoot -Parent
$imgs = Get-Content (Join-Path $root 'research\wiki\all_images.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$byName = @{}
foreach ($i in $imgs) { $byName[$i.name.ToLower()] = $i }
$headers = @{ Referer = 'https://monster-squad.fandom.com/' }
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'

function Save-Art($url, $dir, $id) {
    foreach ($ext in 'png', 'webp', 'jpg') { if (Test-Path (Join-Path $dir "$id.$ext")) { return 'skip' } }
    $tmp = Join-Path $dir "$id.tmp"
    try { Invoke-WebRequest $url -Headers $headers -UserAgent $ua -OutFile $tmp -UseBasicParsing } catch { return "fail $($_.Exception.Message)" }
    $b = [IO.File]::ReadAllBytes($tmp)
    $ext = if ($b[0] -eq 0x89 -and $b[1] -eq 0x50) { 'png' } elseif ($b[0] -eq 0x52 -and $b[8] -eq 0x57) { 'webp' } elseif ($b[0] -eq 0xFF -and $b[1] -eq 0xD8) { 'jpg' } else { '' }
    if ($ext -eq '') { Remove-Item $tmp; return 'fail not an image' }
    Move-Item $tmp (Join-Path $dir "$id.$ext") -Force
    return "ok $ext"
}

if ($args -contains 'skills') {
    # Skill icons named in monsters.json ("Attack All.png" / "Attack_All.png" are the same wiki file).
    $skillDir = Join-Path $root 'assets\skill_icons'
    New-Item -ItemType Directory -Force $skillDir | Out-Null
    $mons = Get-Content (Join-Path $root 'data\monsters.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $names = @{}
    foreach ($m in $mons.PSObject.Properties.Value) {
        foreach ($s in @($m.skills) + @($m.support_skill)) { if ($s.icon) { $names[($s.icon -replace ' ', '_')] = 1 } }
    }
    foreach ($n in $names.Keys) {
        $id = [IO.Path]::GetFileNameWithoutExtension($n).ToLower()
        if (-not $byName.ContainsKey($n.ToLower())) { "skill $n : not on the wiki"; continue }
        $r = Save-Art $byName[$n.ToLower()].url $skillDir $id
        if ($r -notlike 'ok*' -and $r -ne 'skip') { "skill $n : $r" }
    }
    "skill icons: $((Get-ChildItem $skillDir).Count)"
    exit
}

# Monster icons
$iconDir = Join-Path $root 'assets\icons'
New-Item -ItemType Directory -Force $iconDir | Out-Null
$mons = Get-Content (Join-Path $root 'data\monsters.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$ok = 0; $missing = @()
foreach ($m in $mons.PSObject.Properties.Value) {
    $base = ($m.name -replace ' ', '_')
    $hit = $null
    foreach ($cand in "${base}_Icon.png", "${base}_Icon.PNG", "${base}_Icon.jpg", "${base}_Icon2.png") {
        if ($byName.ContainsKey($cand.ToLower())) { $hit = $byName[$cand.ToLower()]; break }
    }
    if ($null -eq $hit) { $missing += $m.id; continue }
    $r = Save-Art $hit.url $iconDir $m.id
    if ($r -like 'ok*' -or $r -eq 'skip') { $ok++ } else { "icon $($m.id): $r" }
}
"icons: $ok saved, $($missing.Count) without a wiki icon"
Set-Content -Encoding utf8 (Join-Path $root 'research\wiki\icons_missing.txt') ($missing -join "`n")

# Island pictures (file names as used on the wiki's island pages)
$islandDir = Join-Path $root 'assets\islands'
New-Item -ItemType Directory -Force $islandDir | Out-Null
$islands = [ordered]@{
    sprout_island = 'Sprout_island.PNG'; lake_island = 'Lake_Island.PNG'; desert_isle = 'Desert_Island.PNG'
    moonlight_desert = 'Moonlight_Desert.PNG'; boneyard_island = 'Boneyard_Island.PNG'; dino_gorge = 'Dino_Gorge.PNG'
    robo_island = 'Robo_Island.PNG'; sky_island = 'Sky_Island.png'; material_island = 'Material_Island.png'
    spirit_island = 'Spirit_Island.PNG'; magic_island = 'Magic_Island.PNG'; jungle_island = 'Jungle_Island.PNG'
    k9_kingdom = 'K9_Kingdom.PNG'; hunters_folly = "Hunter's_Folly.PNG"; treasure_island = 'Treasure_Island.PNG'
    friendship_island = 'Friendship_Island.PNG'
}
foreach ($id in $islands.Keys) {
    $f = $islands[$id].ToLower()
    if (-not $byName.ContainsKey($f)) { "island $id : no file $($islands[$id])"; continue }
    "island $id : " + (Save-Art $byName[$f].url $islandDir $id)
}
