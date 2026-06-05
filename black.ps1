# =============================================
# Fullscreen Black Overlay + Taskbar Hide + Mouse Lock
# Run as Administrator for best results
# =============================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# P/Invoke for mouse cursor and clipping
$code = @"
using System;
using System.Runtime.InteropServices;

public class MouseControl {
    [DllImport("user32.dll")]
    public static extern bool ShowCursor(bool bShow);
    
    [DllImport("user32.dll")]
    public static extern bool ClipCursor(ref RECT lpRect);
    
    [DllImport("user32.dll")]
    public static extern bool GetClipCursor(out RECT lpRect);
    
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
"@
Add-Type -TypeDefinition $code -Language CSharp

# Hide Taskbar on all displays
function Hide-Taskbar {
    $taskbar = Get-Process "explorer" -ErrorAction SilentlyContinue
    if ($taskbar) {
        $taskbar | ForEach-Object { 
            $hwnd = (Get-Process -Id $_.Id).MainWindowHandle
            if ($hwnd) {
                [void][System.Windows.Forms.SendKeys]::SendWait("^{ESC}")
            }
        }
    }
    # Alternative registry method (more reliable)
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "StuckRects3" -Value ([byte[]](0x30,0x00,0x00,0x00,0xFE,0xFF,0xFF,0xFF,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00)) -Force
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

# Create fullscreen black form for each monitor
$forms = @()

foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object System.Windows.Forms.Form
    $form.BackColor = [System.Drawing.Color]::Black
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.Bounds = $screen.Bounds
    $form.Cursor = [System.Windows.Forms.Cursors]::None  # Hide cursor on form
    
    # Make it completely opaque and prevent closing
    $form.KeyPreview = $true
    $form.Add_KeyDown({
        if ($_.KeyCode -eq "Escape") {
        }
    })
    
    $forms += $form
}

# Show all forms
foreach ($f in $forms) {
    $f.Show()
}

# Hide taskbar
Hide-Taskbar

# Hide mouse cursor globally
[MouseControl]::ShowCursor($false)

# Lock mouse to center of primary screen
$primary = [System.Windows.Forms.Screen]::PrimaryScreen
$centerX = $primary.Bounds.X + ($primary.Bounds.Width / 2)
$centerY = $primary.Bounds.Y + ($primary.Bounds.Height / 2)

$rect = New-Object MouseControl+RECT
$rect.Left = $centerX
$rect.Top = $centerY
$rect.Right = $centerX + 1
$rect.Bottom = $centerY + 1

[MouseControl]::ClipCursor([ref]$rect)

Write-Host "Fullscreen black mode activated. Press ESC on any window to exit." -ForegroundColor Red

# Keep script running
try {
    while (-not $global:exitFlag) {
        Start-Sleep -Milliseconds 100
        # Re-apply mouse lock in case something tries to release it
        [MouseControl]::ClipCursor([ref]$rect)
    }
}
finally {
    # Cleanup when exited
    foreach ($f in $forms) {
        if ($f) { $f.Close() }
    }
    [MouseControl]::ShowCursor($true)
    [MouseControl]::ClipCursor([ref]$rect)  # Release cursor
    
    # Restore taskbar
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "StuckRects3" -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "Exited black screen mode." -ForegroundColor Green
}