# RunKeepAliveMaxPerf.ps1  -- Windows PowerShell 5.x compatible
# Purpose:
#   Temporary "long-run" mode for heavy jobs:
#     - Prevent idle Sleep/Hibernate via Win32 execution state heartbeat.
#     - Switch to High performance plan while running.
#     - Attempt to push CPU min/max to 100% (if allowed by policy/OEM).
#   When you close this window, the original plan is restored automatically.
# Notes:
#   - Run with "Right-click > Run with PowerShell".
#   - Some powercfg settings may require Administrator or be blocked by policy/OEM.
#   - This prevents idle sleep/hibernate only; user actions (e.g., closing the lid, shutdown /h) are not blocked.

$ErrorActionPreference = 'Continue'
$host.UI.RawUI.WindowTitle = "KeepAlive + Max Performance (active)"

# Save current plan GUID
$orig = powercfg /getactivescheme
$origGuid = $null
if ($orig -match '{([0-9a-fA-F-]+)}') { $origGuid = $Matches[1] }

try {
    # Switch to High performance
    Write-Host "Switching to High performance plan..." -ForegroundColor Cyan
    powercfg /setactive SCHEME_MAX | Out-Null

    # Try to set CPU min/max = 100% (GUID constants)
    # SUB_PROCESSOR       = 54533251-82be-4824-96c1-47b60b740d00
    # MINPROC (Min state) = 893dee8e-2bef-41e0-89c6-b55d0929964c
    # MAXPROC (Max state) = bc5038f7-23e0-4960-96da-33abaf5935ec
    $SUB_PROCESSOR = '54533251-82be-4824-96c1-47b60b740d00'
    $MINPROC       = '893dee8e-2bef-41e0-89c6-b55d0929964c'
    $MAXPROC       = 'bc5038f7-23e0-4960-96da-33abaf5935ec'

    Write-Host "Pushing CPU min/max to 100% (AC/DC)..." -ForegroundColor Cyan
    try {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT $SUB_PROCESSOR $MINPROC 100 | Out-Null
        powercfg /SETACVALUEINDEX SCHEME_CURRENT $SUB_PROCESSOR $MAXPROC 100 | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT $SUB_PROCESSOR $MINPROC 100 | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT $SUB_PROCESSOR $MAXPROC 100 | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
    } catch {
        Write-Host "Warning: CPU indices could not be set (admin/policy/OEM lock). Continuing..." -ForegroundColor Yellow
    }

    # Prepare Win32 API heartbeat (use decimal to avoid signed int issues on PS5)
    $sig = '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);'
    try { Add-Type -MemberDefinition $sig -Name P -Namespace Win32 -ErrorAction Stop } catch {}

    $ES_CONTINUOUS      = [uint32]2147483648  # 0x80000000
    $ES_SYSTEM_REQUIRED = [uint32]1           # 0x00000001
    # $ES_DISPLAY_REQUIRED = [uint32]2        # 0x00000002 (uncomment to also keep display on)

    Write-Host "KeepAlive is ACTIVE. Close this window to restore defaults." -ForegroundColor Green

    while ($true) {
        [Win32.P]::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED) | Out-Null
        Write-Host ("[{0}] heartbeat" -f (Get-Date -Format "HH:mm:ss")) -ForegroundColor Gray
        Start-Sleep -Seconds 60
    }
}
catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Host "`nRestoring original power plan..." -ForegroundColor Cyan
    if ($origGuid) { powercfg /setactive $origGuid | Out-Null }
    else { powercfg /setactive SCHEME_BALANCED | Out-Null }

    # Clear execution state back to default
    [Win32.P]::SetThreadExecutionState([uint32]2147483648) | Out-Null

    Write-Host "Restored. System back to normal power behavior." -ForegroundColor Green
    Write-Host "`nPress Enter to close this window..."
    [void](Read-Host)
}
