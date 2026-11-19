# Downloads the Monster Squad OST playlist (PLQsoxffuCusQkVc25N7Pak95jbITuSCey) into research/videos/music
# and writes the tracks the APK lacks to assets/music/*.ogg, with silence trimmed. The APK's own Title,
# Boss-01 and Battle-pvp* files were matched to the playlist by chromaprint and are used as they are.
# Run from the project root: powershell -File tools/fetch_music.ps1
$bin = "research/bin"
New-Item -ItemType Directory -Force research/videos/music, assets/music | Out-Null
$tracks = [ordered]@{
	lobby = '-cRF7xAYULY'; sprout = 'jVSR4HhOAbI'; lake = 'khGMOdecN6M'; lake_boss = 'JSS37pkXi4c'
	moonlight_boss = '4C6FONkHaXg'; dino_boss = 'vNAlv8tUj6A'; robo = 'nDSbCCuondI'; robo_boss = 'kJsnl_6aFjM'; boneyard = 'IW1x7zRp0OQ'; desert = 'WVjUAqTzZmM'
}
$gain = @{ boneyard = '13dB' }
foreach ($name in $tracks.Keys) {
	$id = $tracks[$name]
	$mp3 = "research/videos/music/$id.mp3"
	if (-not (Test-Path $mp3)) {
		& "$bin/yt-dlp.exe" -q --no-warnings -x --audio-format mp3 --audio-quality 2 --ffmpeg-location $bin `
			--extractor-args "youtube:player_client=android,web" -o "research/videos/music/%(id)s.%(ext)s" "https://www.youtube.com/watch?v=$id"
	}
	$af = "silenceremove=start_periods=1:start_threshold=-60dB,areverse,silenceremove=start_periods=1:start_threshold=-60dB,areverse"
	if ($gain.ContainsKey($name)) { $af += ",volume=$($gain[$name])" }
	& "$bin/ffmpeg.exe" -v error -y -i $mp3 -af $af -ac 2 -ar 44100 -c:a libvorbis -q:a 5 "assets/music/$name.ogg"
	"MUSIC $name <- $id"
}
