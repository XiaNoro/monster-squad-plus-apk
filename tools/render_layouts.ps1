# Renders original layout files to PNGs for checking against footage.
# Usage: powershell -File tools/render_layouts.ps1 -Out <dir> R_main+R_top2 R_shopPage ...
# Extra game flags (e.g. -Screen hub) render a real screen instead of a raw layout.
[CmdletBinding(PositionalBinding = $false)]
param([string]$Out = '.', [string]$Screen = '', [string]$Arg = '', [string]$Tag = '', [string]$Extra = '', [double]$At = 1, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Names)

$godot = 'E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$root = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Force $Out | Out-Null
if ($Screen -ne '') { $Names = @($Screen) }
foreach ($n in $Names) {
    $file = Join-Path $Out ('lay_' + $n.Replace('+', '_') + $Tag + '.png')
    $what = if ($Screen -ne '') { "--screen=$n" } else { "--layout=$n" }
    $err = Join-Path $Out 'render_err.txt'
    $gameArgs = @('--path', $root, '--fixed-fps', '60', '--quit-after', '400', '--', '--test-save', '--test-nopopup', $what, "--shot=$file@$At")
    if ($Extra -ne '') { $gameArgs += $Extra.Split(' ') }
    if ($Arg -ne '') { foreach ($a in $Arg.Split(';')) { $gameArgs += "--arg=$a" } }
    $p = Start-Process $godot -ArgumentList $gameArgs -PassThru -RedirectStandardError $err -RedirectStandardOutput (Join-Path $Out 'render_out.txt')
    if (-not $p.WaitForExit(60000)) { $p.Kill(); "$n : timed out" }
    Get-Content $err | Select-String 'ERROR|SCRIPT' | Select-Object -First 6 | ForEach-Object { "$n : $_" }
    "$n -> $file"
}
