[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Destination)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

function New-Logo {
    param([string]$Name, [int]$Width, [int]$Height)

    $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $blue = [System.Drawing.Color]::FromArgb(70, 94, 255)
        $brush = New-Object System.Drawing.SolidBrush $blue
        $diameter = [Math]::Min($Width, $Height) * 0.78
        $x = ($Width - $diameter) / 2
        $y = ($Height - $diameter) / 2
        $graphics.FillEllipse($brush, $x, $y, $diameter, $diameter)
        $fontSize = [Math]::Max(10, [Math]::Min($Width, $Height) * 0.37)
        $font = New-Object System.Drawing.Font 'Segoe UI', $fontSize, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        $graphics.DrawString('T', $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, 0, $Width, $Height), $format)
    }
    finally {
        if ($format) { $format.Dispose() }
        if ($font) { $font.Dispose() }
        if ($brush) { $brush.Dispose() }
        $graphics.Dispose()
    }
    try { $bitmap.Save((Join-Path $Destination $Name), [System.Drawing.Imaging.ImageFormat]::Png) }
    finally { $bitmap.Dispose() }
}

New-Logo 'Square44x44Logo.png' 44 44
New-Logo 'Square150x150Logo.png' 150 150
New-Logo 'Wide310x150Logo.png' 310 150
New-Logo 'StoreLogo.png' 50 50
