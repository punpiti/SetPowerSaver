# SetPowerSaver.ps1  -- Windows PowerShell 5.x compatible
# Purpose:
#   Enable Hibernate, switch to Power Saver plan, and configure display/sleep/hibernate timeouts.
# Notes:
#   - Run with "Right-click > Run with PowerShell" (Windows PowerShell 5).
#   - If policy blocks scripts, run once:
#       Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
#       Unblock-File "$HOME\Desktop\SetPowerSaver.ps1"

$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = "SetPowerSaver - configure power saver"

Write-Host "Enabling Hibernate..." -ForegroundColor Cyan
powercfg /hibernate on | Out-Null

Write-Host "Switching to Power saver plan..." -ForegroundColor Cyan
powercfg /setactive SCHEME_MIN | Out-Null

# --- Timeouts (tune as needed) ---
# AC (plugged in)
powercfg /change monitor-timeout-ac 10    | Out-Null  # turn off display after 10 minutes
powercfg /change standby-timeout-ac 30    | Out-Null  # sleep after 30 minutes
powercfg /change hibernate-timeout-ac 180 | Out-Null  # hibernate after 180 minutes

# DC (on battery)
powercfg /change monitor-timeout-dc 5     | Out-Null  # turn off display after 5 minutes
powercfg /change standby-timeout-dc 15    | Out-Null  # sleep after 15 minutes
powercfg /change hibernate-timeout-dc 60  | Out-Null  # hibernate after 60 minutes

Write-Host "Done. Power saver with display/sleep/hibernate timeouts configured." -ForegroundColor Green
Write-Host "`nPress Enter to close this window..."
[void](Read-Host)
