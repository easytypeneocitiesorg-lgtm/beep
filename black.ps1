# =============================================
# Fullscreen Black Screen + Taskbar Hide + Mouse Lock (Top Middle)
# NO ESC EXIT - Must be killed via Task Manager
# =============================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# P/Invoke for mouse control
$code = @"
using System;
using System.Runtime.InteropServices;

public class MouseControl {
    [DllImport("user32.dll")]
    public static extern bool ShowCursor(bool bShow);
    
    [DllImport("user32.dll")]
    public static extern bool ClipCursor(ref RECT lpRect);
    
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
"@
Add-Type -TypeDefinition $code -Language CSharp

# Hide Taskbar
function Hide-Taskbar {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "StuckRects3" -Value ([byte[]](0x30,0x00,0x00,0x00,0xFE,0xFF,0xFF,0xFF,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00)) -Force
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

# Create fullscreen black form on EVERY monitor
$forms = @()

foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object System.Windows.Forms.Form
    $form.BackColor = [System.Drawing.Color]::Black
    $form.FormBorderStyle = "None"
    $form.WindowState = "Maximized"
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.StartPosition = "Manual"
    $form.Bounds = $screen.Bounds
    $form.Cursor = [System.Windows.Forms.Cursors]::None
    
    $forms += $form
}

# Show all forms
foreach ($f in $forms) { $f.Show() }

# Hide taskbar
Hide-Taskbar

# Hide mouse cursor globally
[MouseControl]::ShowCursor($false)

# ================== MOUSE LOCKED TO TOP MIDDLE ==================
$primary = [System.Windows.Forms.Screen]::PrimaryScreen
$centerX = $primary.Bounds.X + ($primary.Bounds.Width / 2)
$topY    = $primary.Bounds.Y + 10   # 10 pixels from the very top (adjust if needed)

$rect = New-Object MouseControl+RECT
$rect.Left   = $centerX
$rect.Top    = $topY
$rect.Right  = $centerX + 1
$rect.Bottom = $topY + 1

[MouseControl]::ClipCursor([ref]$rect)

Write-Host "BLACK SCREEN MODE ACTIVATED (Mouse locked to Top Middle)" -ForegroundColor Red
Write-Host "To exit: Task Manager → End PowerShell" -ForegroundColor Yellow

# Keep running forever + constantly re-lock mouse
try {
    while ($true) {
        Start-Sleep -Milliseconds 50
        [MouseControl]::ClipCursor([ref]$rect)   # Re-apply lock
    }
}
finally {
    # Cleanup
    foreach ($f in $forms) {
        if ($f) { $f.Close() }
    }
    [MouseControl]::ShowCursor($true)
    Start-Process explorer.exe
}
