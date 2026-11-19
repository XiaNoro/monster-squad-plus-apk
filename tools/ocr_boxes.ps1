# OCRs a list of frames with the built-in Windows OCR engine and keeps where each line is.
# Input: a text file with one image path per line. Output: JSON lines {"file": path, "lines": [{"text", "x", "y", "w", "h"}]}
# appended to the output file; frames already in it are skipped.
# Usage: powershell -File tools/ocr_boxes.ps1 <list.txt> <out.jsonl>
param([string]$List, [string]$Out)

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType = WindowsRuntime]

$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]
function Await($op, [Type]$type) {
    $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
    $t.Wait() | Out-Null
    $t.Result
}

$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
$done = @{}
if (Test-Path $Out) {
    foreach ($l in [IO.File]::ReadAllLines($Out)) { if ($l -match '"file":\s*"([^"]+)"') { $done[$Matches[1].Replace('\\', '\')] = $true } }
}
$writer = New-Object IO.StreamWriter($Out, $true, (New-Object Text.UTF8Encoding $false))
$n = 0
foreach ($path in [IO.File]::ReadAllLines($List)) {
    if ($path -eq '' -or $done.ContainsKey($path)) { continue }
    $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
    $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    $lines = foreach ($line in $result.Lines) {
        $r = $line.Words | ForEach-Object { $_.BoundingRect }
        $x0 = ($r | Measure-Object X -Minimum).Minimum; $y0 = ($r | Measure-Object Y -Minimum).Minimum
        $x1 = ($r | ForEach-Object { $_.X + $_.Width } | Measure-Object -Maximum).Maximum
        $y1 = ($r | ForEach-Object { $_.Y + $_.Height } | Measure-Object -Maximum).Maximum
        @{ text = $line.Text; x = [int]$x0; y = [int]$y0; w = [int]($x1 - $x0); h = [int]($y1 - $y0) }
    }
    $writer.WriteLine((@{ file = $path; lines = @($lines) } | ConvertTo-Json -Compress -Depth 4))
    $stream.Dispose()
    $n++
}
$writer.Close()
"ocr boxes: $n frames -> $Out"
