# RunKeepAliveMaxPerf.ps1  -- Windows PowerShell 5.x
# --------------------------------------------------------------------
# Purpose:
#   - Keep the system awake (no idle sleep / display-off) while running.
#   - If running with Administrator privileges, temporarily switch
#     the active power plan to "High performance" (SCHEME_MIN) and
#     restore the original plan safely when the script stops
#     (including Ctrl+C).
#
# Notes:
#   - SetThreadExecutionState is per-thread and does NOT require admin.
#   - powercfg /setactive and some power changes typically DO require admin.
#   - This script is designed to degrade gracefully when not run as admin:
#       * Keep-alive still works.
#       * Power plan is not changed.
#       * No restore is attempted.
# --------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = "KeepAlive + Max Performance (PS5)"

# --------------------------------------------------------------------
# Function: Test-IsAdmin
# --------------------------------------------------------------------
function Test-IsAdmin {
    $principal = New-Object Security.Principal.WindowsPrincipal `
        ([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

$IsAdmin = Test-IsAdmin

if ($IsAdmin) {
    Write-Host "[INFO] Running with Administrator privileges." -ForegroundColor Green
} else {
    Write-Warning "[WARN] Not running as Administrator. Power plan change (High performance / restore) will be skipped. Keep-alive only."
}

# --------------------------------------------------------------------
# Add the Win32 API: SetThreadExecutionState
#   ใช้ -TypeDefinition อย่างเดียว ไม่ใส่ -Name/-Namespace
#   และใช้ single-quoted here-string เพื่อเลี่ยงปัญหา escape/quote
# --------------------------------------------------------------------
if (-not ("PowerNative" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class PowerNative {
    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
'@
}

# Flags for SetThreadExecutionState
$ES_CONTINUOUS       = [uint32]2147483648
$ES_SYSTEM_REQUIRED  = [uint32]1
$ES_DISPLAY_REQUIRED = [uint32]2



# --------------------------------------------------------------------
# Capture the current active power plan GUID (best effort).
# --------------------------------------------------------------------
$origGuid = $null
try {
    $out = powercfg /getactivescheme 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) {
        # Expected format:
        #   "Power Scheme GUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  (Friendly name)"
        $tokens = $out -split '\s+'
        foreach ($tok in $tokens) {
            if ($tok -match '^[0-9a-fA-F-]{36}$') {
                $origGuid = $tok
                break
            }
        }
    } else {
        Write-Warning "[WARN] powercfg /getactivescheme returned non-zero exit code."
    }
}
catch {
    Write-Warning "[WARN] Exception while reading original power plan: $($_.Exception.Message)"
}

Write-Host "[INFO] Original power plan GUID: $origGuid" -ForegroundColor DarkCyan

# --------------------------------------------------------------------
# Main logic: try/finally so that cleanup & restore happen even
# when user presses Ctrl+C or an error occurs.
# --------------------------------------------------------------------
try {
    # --- Attempt to switch power plan (admin only) ---
    if ($IsAdmin) {
        Write-Host ""
        Write-Host "[INFO] Switching to High performance plan (SCHEME_MIN)..." -ForegroundColor Cyan
        powercfg /setactive SCHEME_MIN 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "[WARN] Failed to switch to SCHEME_MIN. Continuing with current plan."
        } else {
            Write-Host "[INFO] High performance plan requested." -ForegroundColor Green
        }
    } else {
        Write-Host ""
        Write-Host "[INFO] Running without admin rights - power plan will NOT be changed." -ForegroundColor Yellow
    }

    # --- Enable keep-alive behavior ---
    Write-Host "[INFO] Disabling idle sleep / display-off while this script runs..." -ForegroundColor Cyan
    [PowerNative]::SetThreadExecutionState(
        $ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED
    ) | Out-Null

    Write-Host ""
    Write-Host "[INFO] KeepAlive is now active." -ForegroundColor Green
    if ($IsAdmin) {
        Write-Host "[INFO] If the 'High performance' switch succeeded, the system is now in max performance mode." -ForegroundColor Green
    }
    Write-Host "[INFO] Press Ctrl+C in this window to stop and trigger restore/cleanup." -ForegroundColor Yellow
    Write-Host ""

    # Main wait loop
    while ($true) {
        Start-Sleep -Seconds 60
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Host ""
    Write-Host "[INFO] Cleaning up execution state..." -ForegroundColor Cyan

    # Clear the display/system required bits, leaving only ES_CONTINUOUS.
    [PowerNative]::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null

    if ($IsAdmin) {
        Write-Host "[INFO] Restoring original power plan..." -ForegroundColor Cyan

        if ($origGuid) {
            powercfg /setactive $origGuid 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "[WARN] Failed to restore original plan by GUID. Falling back to Balanced (SCHEME_BALANCED)."
                powercfg /setactive SCHEME_BALANCED 2>$null
            } else {
                Write-Host "[INFO] Original power plan restored successfully." -ForegroundColor Green
            }
        } else {
            Write-Warning "[WARN] No original plan GUID captured. Using Balanced (SCHEME_BALANCED) as fallback."
            powercfg /setactive SCHEME_BALANCED 2>$null
        }
    } else {
        Write-Host "[INFO] No power plan change was performed (no admin rights), so no restore is needed." -ForegroundColor Yellow
    }

    Write-Host ""
    Read-Host "Press Enter to close this window"
}
