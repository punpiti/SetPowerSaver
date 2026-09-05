# SetPowerMode.ps1 -- Windows PowerShell 5.x
# Central implementation for the persistent power modes in this folder.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('PowerSaver', 'Quiet', 'Coding', 'Focus', 'Presentation', 'Battery', 'Normal', 'CompileBoost', 'KeepAliveMaxPerf')]
    [string]$Mode
)

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $principal = New-Object Security.Principal.WindowsPrincipal `
        ([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-PowerCfg {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & powercfg @Arguments 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "powercfg $($Arguments -join ' ') failed (exit code $LASTEXITCODE). The setting may be unavailable or managed by policy."
        return $false
    }
    return $true
}

function Set-Timeouts {
    param(
        [int]$MonitorAc, [int]$StandbyAc, [int]$HibernateAc,
        [int]$MonitorDc, [int]$StandbyDc, [int]$HibernateDc
    )

    Invoke-PowerCfg @('/change', 'monitor-timeout-ac', $MonitorAc) | Out-Null
    Invoke-PowerCfg @('/change', 'standby-timeout-ac', $StandbyAc) | Out-Null
    Invoke-PowerCfg @('/change', 'hibernate-timeout-ac', $HibernateAc) | Out-Null
    Invoke-PowerCfg @('/change', 'monitor-timeout-dc', $MonitorDc) | Out-Null
    Invoke-PowerCfg @('/change', 'standby-timeout-dc', $StandbyDc) | Out-Null
    Invoke-PowerCfg @('/change', 'hibernate-timeout-dc', $HibernateDc) | Out-Null
}

function Set-ProcessorLimits {
    param(
        [int]$MaximumAc, [int]$MaximumDc,
        [ValidateSet('Unchanged', 'Disabled', 'Enabled')][string]$Boost = 'Unchanged'
    )

    foreach ($source in 'ac', 'dc') {
        $maximum = if ($source -eq 'ac') { $MaximumAc } else { $MaximumDc }
        Invoke-PowerCfg @("/set${source}valueindex", 'scheme_current', 'sub_processor', 'PROCTHROTTLEMIN', 5) | Out-Null
        Invoke-PowerCfg @("/set${source}valueindex", 'scheme_current', 'sub_processor', 'PROCTHROTTLEMAX', $maximum) | Out-Null
        if ($Boost -ne 'Unchanged') {
            # Turbo Boost commonly causes abrupt fan noise. Value 0 disables it;
            # 2 is Windows' normal Aggressive/Enabled behaviour.
            $boostValue = if ($Boost -eq 'Disabled') { 0 } else { 2 }
            Invoke-PowerCfg @("/set${source}valueindex", 'scheme_current', 'sub_processor', 'PERFBOOSTMODE', $boostValue) | Out-Null
        }
    }
}

function Show-HibernateInPowerMenu {
    $powerKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'
    $flyoutKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'
    $policyKey = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\HideHibernate'

    New-ItemProperty -Path $powerKey -Name 'HibernateEnabled' -PropertyType DWord -Value 1 -Force | Out-Null
    if (-not (Test-Path $flyoutKey)) { New-Item -Path $flyoutKey -Force | Out-Null }
    New-ItemProperty -Path $flyoutKey -Name 'ShowHibernateOption' -PropertyType DWord -Value 1 -Force | Out-Null
    if (-not (Test-Path $policyKey)) { New-Item -Path $policyKey -Force | Out-Null }
    New-ItemProperty -Path $policyKey -Name 'value' -PropertyType DWord -Value 0 -Force | Out-Null
}

function Start-KeepAliveMaxPerformance {
    param([bool]$IsAdmin)

    if (-not ('PowerNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class PowerNative {
    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
'@
    }

    $esContinuous = [uint32]2147483648
    $esSystemRequired = [uint32]1
    $esDisplayRequired = [uint32]2
    $originalGuid = $null

    try {
        $activeScheme = powercfg /getactivescheme 2>$null
        if ($LASTEXITCODE -eq 0 -and $activeScheme) {
            foreach ($token in ($activeScheme -split '\s+')) {
                if ($token -match '^[0-9a-fA-F-]{36}$') {
                    $originalGuid = $token
                    break
                }
            }
        }

        if ($IsAdmin) {
            Write-Host '[INFO] Switching temporarily to High performance...' -ForegroundColor Cyan
            Invoke-PowerCfg @('/setactive', 'SCHEME_MIN') | Out-Null
        } else {
            Write-Warning 'Not elevated: Keep Alive will work, but the power plan will not change.'
        }

        [PowerNative]::SetThreadExecutionState(
            $esContinuous -bor $esSystemRequired -bor $esDisplayRequired
        ) | Out-Null
        Write-Host '[ACTIVE] Keep Alive is on. Press Ctrl+C to stop and restore the previous plan.' -ForegroundColor Green

        while ($true) { Start-Sleep -Seconds 60 }
    }
    finally {
        [PowerNative]::SetThreadExecutionState($esContinuous) | Out-Null
        if ($IsAdmin) {
            if ($originalGuid) {
                Invoke-PowerCfg @('/setactive', $originalGuid) | Out-Null
            } else {
                Invoke-PowerCfg @('/setactive', 'SCHEME_BALANCED') | Out-Null
            }
            Write-Host '[DONE] Keep Alive stopped; power plan restored.' -ForegroundColor Green
        }
    }
}

$isAdmin = Test-IsAdmin
if (-not $isAdmin -and $Mode -notin 'KeepAliveMaxPerf', 'CompileBoost') {
    Write-Warning 'Run PowerShell as Administrator for reliable power and hibernation changes.'
}

if ($Mode -in 'KeepAliveMaxPerf', 'CompileBoost') {
    Start-KeepAliveMaxPerformance -IsAdmin $isAdmin
    return
}

switch ($Mode) {
    'PowerSaver' {
        if ($isAdmin) {
            Invoke-PowerCfg @('/hibernate', 'on') | Out-Null
            Show-HibernateInPowerMenu
        }
        Invoke-PowerCfg @('/setactive', 'SCHEME_MAX') | Out-Null
        Set-Timeouts 10 30 180 5 15 60
        $summary = 'Power Saver: AC display/sleep/hibernate 10/30/180 min; battery 5/15/60 min.'
    }
    'Quiet' {
        if ($isAdmin) { Invoke-PowerCfg @('/hibernate', 'off') | Out-Null }
        Set-Timeouts 1 0 0 1 0 0
        Set-ProcessorLimits 50 40 -Boost Disabled
        $summary = 'Quiet: no sleep, display off after 1 min, CPU capped at 50% AC / 40% battery; Turbo Boost disabled.'
    }
    'Coding' {
        if ($isAdmin) { Invoke-PowerCfg @('/hibernate', 'on') | Out-Null }
        Set-Timeouts 15 60 180 5 30 60
        Set-ProcessorLimits 75 60 -Boost Disabled
        $summary = 'Coding: CPU capped at 75% AC / 60% battery and Turbo Boost disabled to reduce fan noise; sleep after 60/30 min.'
    }
    'Focus' {
        if ($isAdmin) { Invoke-PowerCfg @('/hibernate', 'on') | Out-Null }
        # For writing, reading, watching stock prices, or dashboards: the
        # screen must remain visible even while the user is not typing.
        Set-Timeouts 0 0 0 0 0 0
        Set-ProcessorLimits 60 50 -Boost Disabled
        $summary = 'Focus: screen stays on and PC stays awake for writing, reading, stocks, or dashboards; quiet CPU limits at 60% AC / 50% battery.'
    }
    'Presentation' {
        if ($isAdmin) { Invoke-PowerCfg @('/hibernate', 'on') | Out-Null }
        Set-Timeouts 0 0 0 0 0 0
        Set-ProcessorLimits 75 60 -Boost Disabled
        $summary = 'Presentation: screen stays on and the PC stays awake for meetings, teaching, and screen sharing; moderate CPU limits reduce fan noise.'
    }
    'Battery' {
        if ($isAdmin) { Invoke-PowerCfg @('/hibernate', 'on') | Out-Null }
        Invoke-PowerCfg @('/setactive', 'SCHEME_MAX') | Out-Null
        Set-Timeouts 5 15 60 2 10 30
        Set-ProcessorLimits 50 40 -Boost Disabled
        $summary = 'Battery: Power Saver with CPU capped at 50% AC / 40% battery, Turbo Boost disabled, and short timeouts.'
    }
    'Normal' {
        if ($isAdmin) { Invoke-PowerCfg @('/hibernate', 'on') | Out-Null }
        Set-Timeouts 15 30 180 5 15 60
        Set-ProcessorLimits 100 100 -Boost Enabled
        $summary = 'Normal: CPU range and Turbo Boost restored; standard display/sleep/hibernate timeouts applied.'
    }
}

Invoke-PowerCfg @('/setactive', 'scheme_current') | Out-Null
Write-Host "[DONE] $summary" -ForegroundColor Green
