# Tiles full video frames at given times (seconds) into labelled 4x3 contact sheets.
# Usage: powershell -File tools/frame_sheet.ps1 <video> <out prefix> 28,31,34.5,...
param([string]$Video, [string]$Out, [string]$Times)

$root = Split-Path $PSScriptRoot -Parent
$ff = Join-Path $root 'research\bin\ffmpeg.exe'
Add-Type -AssemblyName System.Drawing
$ts = $Times.Split(',') | ForEach-Object { [double]$_ }
$tmp = Join-Path ([IO.Path]::GetDirectoryName($Out)) 'fs_tmp.png'
$per = 12
for ($s = 0; $s * $per -lt $ts.Count; $s++) {
    $bmp = New-Object System.Drawing.Bitmap 1920, 1080
    $gr = [System.Drawing.Graphics]::FromImage($bmp)
    $gr.Clear([System.Drawing.Color]::Black)
    for ($k = 0; $k -lt $per -and $s * $per + $k -lt $ts.Count; $k++) {
        $t = $ts[$s * $per + $k]
        & $ff -loglevel error -y -ss $t -i $Video -frames:v 1 $tmp
        $im = [System.Drawing.Image]::FromFile($tmp)
        $x = ($k % 4) * 480; $y = [Math]::Floor($k / 4) * 360
        $gr.DrawImage($im, $x, $y, 480, 360)
        $im.Dispose()
        $gr.FillRectangle([System.Drawing.Brushes]::Black, $x, $y, 70, 20)
        $gr.DrawString(('{0}s' -f $t), (New-Object System.Drawing.Font 'Arial', 11, ([System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Yellow, $x + 2, $y + 1)
    }
    $bmp.Save("${Out}_$s.png")
    $gr.Dispose(); $bmp.Dispose()
    "${Out}_$s.png"
}
