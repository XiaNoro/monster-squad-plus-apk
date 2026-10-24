# Prints an indented outline of a layout file: type, elementID, position, image / label text.
# Usage: powershell -File tools/layout_outline.ps1 R_main [MaxDepth]
param([string]$Name, [int]$MaxDepth = 99)

$root = Split-Path $PSScriptRoot -Parent
[xml]$x = Get-Content -Raw -Encoding UTF8 (Join-Path $root "data\layouts\$Name.xml")

function Walk($node, $depth) {
    foreach ($n in $node.ElementNode) {
        if ($depth -gt $MaxDepth) { return }
        $extra = if ($n.labelContent -ne $null) { '"' + $n.labelContent + '" ' + $n.fontSize } elseif ($n.imageName) { $n.imageName } else { '' }
        $size = if ($n.ninePatchSize) { ' ' + $n.ninePatchSize } elseif ($n.areaSizeX) { " {$($n.areaSizeX),$($n.areaSizeY)}" } else { '' }
        ('  ' * $depth) + "$($n.type) $($n.elementID) ($($n.positionX),$($n.positionY))$size $extra"
        Walk $n ($depth + 1)
    }
}
Walk $x.root 0
