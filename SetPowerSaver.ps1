# SetPowerSaver.ps1  -- Windows PowerShell 5.x
# --------------------------------------------------------------------
# Purpose:
#   - Enable Hibernate.
#   - Ensure Hibernate is visible in Start / Power menu (when possible).
#   - Switch to "Power saver" plan (SCHEME_MAX) where possible.
#   - Configure display/sleep/hibernate timeouts for AC and DC.
#
# Admin behavior:
#   - /hibernate on  และการแก้ HKLM ต้องใช้ Admin แน่นอน -> ถ้าไม่ใช่ Admin จะ SKIP พร้อมเตือน
#   - /setactive SCHEME_MAX และ /change timeout:
#       * พยายามรันเสมอ
#       * ถ้าทำไม่ได้ค่อยเตือน (อาจเพราะสิทธิ์ไม่พอหรือ policy บล็อก)
# --------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = "SetPowerSaver - Power Saver Mode (PS5)"

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
    Write-Host "[INFO] Running as standard user. Some steps that *require* admin will be skipped, others will be attempted normally." -ForegroundColor Yellow
}

# --------------------------------------------------------------------
# STEP 1: Enable Hibernate (must be admin)
# --------------------------------------------------------------------
Write-Host ""
Write-Host "[STEP] Enabling Hibernate (powercfg /hibernate on)..." -ForegroundColor Cyan

if ($IsAdmin) {
    powercfg /hibernate on 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "[WARN] Failed to enable Hibernate via powercfg. This may be blocked by policy."
    } else {
        Write-Host "[INFO] Hibernate has been enabled (or was already enabled)." -ForegroundColor Green
    }
} else {
    Write-Warning "[SKIP] Skipping 'powercfg /hibernate on' because this command requires Administrator privileges."
}

# --------------------------------------------------------------------
# STEP 2: Ensure Hibernate shows in Start / Power menu (HKLM registry, must be admin)
# --------------------------------------------------------------------
Write-Host ""
Write-Host "[STEP] Ensuring 'Hibernate' appears in Start / Power menu..." -ForegroundColor Cyan

if ($IsAdmin) {
    # 2.1) Core flag: HibernateEnabled
    $powerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    if (Test-Path $powerKey) {
        New-ItemProperty -Path $powerKey -Name "HibernateEnabled" `
            -PropertyType DWord -Value 1 -Force | Out-Null
        Write-Host "[INFO] HibernateEnabled=1 set under HKLM:\SYSTEM\CurrentControlSet\Control\Power" -ForegroundColor Green
    } else {
        Write-Warning "[WARN] Power key not found: HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    }

    # 2.2) Flyout menu setting: ShowHibernateOption = 1
    $flyoutKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings"
    if (-not (Test-Path $flyoutKey)) {
        New-Item -Path $flyoutKey -Force | Out-Null
        Write-Host "[INFO] Created key: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -ForegroundColor Green
    }
    New-ItemProperty -Path $flyoutKey -Name "ShowHibernateOption" `
        -PropertyType DWord -Value 1 -Force | Out-Null
    Write-Host "[INFO] ShowHibernateOption=1 set under HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -ForegroundColor Green

    # 2.3) PolicyManager: Do not hide Hibernate
    $policyKey = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\HideHibernate"
    if (-not (Test-Path $policyKey)) {
        New-Item -Path $policyKey -Force | Out-Null
        Write-Host "[INFO] Created key: HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\HideHibernate" -ForegroundColor Green
    }
    New-ItemProperty -Path $policyKey -Name "value" `
        -PropertyType DWord -Value 0 -Force | Out-Null
    Write-Host "[INFO] PolicyManager HideHibernate.value=0 set under HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\HideHibernate" -ForegroundColor Green
}
else {
    Write-Warning "[SKIP] Skipping registry changes for Hibernate menu (HKLM:\...) because they require Administrator privileges."
}

# --------------------------------------------------------------------
# STEP 3: Switch to Power saver plan (SCHEME_MAX) - try always, warn on failure
# --------------------------------------------------------------------
Write-Host ""
Write-Host "[STEP] Switching to Power saver plan (SCHEME_MAX)..." -ForegroundColor Cyan

try {
    powercfg /setactive SCHEME_MAX 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "[WARN] Failed to switch to SCHEME_MAX (Power saver). This may require admin rights or be blocked by policy."
    } else {
        Write-Host "[INFO] Power saver plan has been requested as the active plan." -ForegroundColor Green
    }
}
catch {
    Write-Warning "[WARN] Exception while switching to SCHEME_MAX: $($_.Exception.Message)"
    Write-Warning "[WARN] This operation may require Administrator privileges or may be blocked."
}

# --------------------------------------------------------------------
# STEP 4: Configure display / sleep / hibernate timeouts - try always, warn on failure
# --------------------------------------------------------------------
Write-Host ""
Write-Host "[STEP] Configuring display / sleep / hibernate timeouts..." -ForegroundColor Cyan

try {
    # AC (plugged in)
    powercfg /change monitor-timeout-ac 10    | Out-Null  # display off after 10 minutes
    powercfg /change standby-timeout-ac 30    | Out-Null  # sleep after 30 minutes
    powercfg /change hibernate-timeout-ac 180 | Out-Null  # hibernate after 180 minutes

    # DC (battery)
    powercfg /change monitor-timeout-dc 5     | Out-Null  # display off after 5 minutes
    powercfg /change standby-timeout-dc 15    | Out-Null  # sleep after 15 minutes
    powercfg /change hibernate-timeout-dc 60  | Out-Null  # hibernate after 60 minutes

    Write-Host "[INFO] Timeout configuration commands were issued (some values may still be blocked by policy)." -ForegroundColor Green
}
catch {
    Write-Warning "[WARN] One or more timeout settings could not be changed: $($_.Exception.Message)"
    Write-Warning "[WARN] This may require Administrator rights or may be blocked by group policy."
}

# --------------------------------------------------------------------
# SUMMARY
# --------------------------------------------------------------------
Write-Host ""
Write-Host "[SUMMARY] Power Saver configuration steps finished (best effort)." -ForegroundColor Green
if (-not $IsAdmin) {
    Write-Host "[NOTE] Admin-only steps (Hibernate enable, HKLM registry) were skipped. Other powercfg operations were attempted and may partially succeed depending on policy." -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to close this window"
