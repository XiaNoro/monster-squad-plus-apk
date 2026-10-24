# Contact sheets of the enemy side during each battle's last wave (from tools/segment_stages.py),
# 2 crops per battle, labelled with the field name and time.  Usage: powershell -File tools/boss_sheets.ps1 <id> <out dir>
param([string]$Id, [string]$Out)
$py = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
$v = (Get-ChildItem research/videos/video_hd -Filter "$Id.mp4").FullName
New-Item -ItemType Directory -Force $Out | Out-Null
Get-ChildItem $Out -Filter "b_*.png" | Remove-Item -Confirm:$false
$k = 0
foreach ($line in (& $py -I tools/segment_stages.py $Id)) {
    if ($line -notmatch '^\s*(\d+)-\s*(\d+)\s+(\S+)\s+waves=\d+ last=(\d+|None)') { continue }
    $start = [int]$matches[1]; $end = [int]$matches[2]; $field = $matches[3]
    $last = if ($matches[4] -eq 'None') { $end - 6 } else { [int]$matches[4] }
    foreach ($t in @(($last + 2), [math]::Min($end - 1, $last + 9))) {
        $k++
        & research/bin/ffmpeg.exe -loglevel error -y -ss $t -i $v -frames:v 1 -vf "crop=iw*0.6:ih*0.72:iw*0.4:ih*0.06,scale=420:-1,pad=iw:ih+28:0:28:black" "$Out/tmp.png"
        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Image]::FromFile((Resolve-Path "$Out/tmp.png"))
        $g = [System.Drawing.Graphics]::FromImage($img)
        $g.DrawString("$field  t=$t", (New-Object System.Drawing.Font("Arial", 13, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Yellow, 4, 4)
        $img.Save((Join-Path (Resolve-Path $Out) ("b_{0:D3}.png" -f $k)))
        $g.Dispose(); $img.Dispose()
    }
}
Remove-Item "$Out/tmp.png" -ErrorAction SilentlyContinue
& research/bin/ffmpeg.exe -loglevel error -y -framerate 1 -i "$Out/b_%03d.png" -vf "tile=4x4" "$Out/sheet_%02d.png"
"$k crops"
