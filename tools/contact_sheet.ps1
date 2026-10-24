# Tiles video frames into labelled contact sheets for quick visual review.
# Usage: powershell -File tools/contact_sheet.ps1 <frames dir> <out.png> [-From 0] [-To 99999] [-Step 1] [-Cols 4] [-Rows 3]
param([string]$Dir, [string]$Out, [int]$From = 0, [int]$To = 99999, [int]$Step = 1, [int]$Cols = 4, [int]$Rows = 3)

Add-Type -AssemblyName System.Drawing
$files = Get-ChildItem $Dir -Filter *.jpg | Where-Object { [int]$_.BaseName -ge $From -and [int]$_.BaseName -le $To } | Sort-Object Name
$files = for ($i = 0; $i -lt $files.Count; $i += $Step) { $files[$i] }
$files = @($files | Select-Object -First ($Cols * $Rows))
$w = 427; $h = 240
$sheet = New-Object System.Drawing.Bitmap ($Cols * $w), ($Rows * $h)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::Black)
$font = New-Object System.Drawing.Font 'Arial', 14, ([System.Drawing.FontStyle]::Bold)
for ($i = 0; $i -lt $files.Count; $i++) {
    $img = [System.Drawing.Image]::FromFile($files[$i].FullName)
    $x = ($i % $Cols) * $w; $y = [math]::Floor($i / $Cols) * $h
    $g.DrawImage($img, $x, $y, $w, $h)
    $t = [int]$files[$i].BaseName
    $label = '{0}:{1:D2}' -f [math]::Floor($t / 60), ($t % 60)
    $g.FillRectangle([System.Drawing.Brushes]::Black, $x, $y, 62, 22)
    $g.DrawString($label, $font, [System.Drawing.Brushes]::Yellow, $x + 2, $y + 1)
    $img.Dispose()
}
$sheet.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $sheet.Dispose()
"sheet: $($files.Count) frames -> $Out"
