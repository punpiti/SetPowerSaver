param(
    [string]$RepoPath = ".",
    [string]$Message
)

$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = "GitUpdate - Sync with GitHub"

function Fail {
    param([string]$Msg)
    Write-Host "[ERROR] $Msg" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] GitUpdate starting..." -ForegroundColor Cyan

# 1) Check git
try {
    git --version 1>$null 2>$null
} catch {
    Fail "git not found. Please install Git and ensure it's on PATH."
}
Write-Host "[INFO] git is available." -ForegroundColor Green

# 2) Normalize repo path
$fullRepoPath = (Resolve-Path -Path $RepoPath -ErrorAction Stop).Path
if (-not (Test-Path (Join-Path $fullRepoPath ".git"))) {
    Fail "No .git folder found in '$fullRepoPath'. This is not a git repository."
}

Write-Host "[INFO] Using repository: $fullRepoPath" -ForegroundColor Cyan
Push-Location $fullRepoPath
try {
    # 3) Check status
    $status = git status --porcelain
    if ($LASTEXITCODE -ne 0) {
        Fail "git status failed."
    }

    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host "[INFO] No local changes detected." -ForegroundColor Yellow
        Write-Host "[STEP] Pulling latest changes (fast-forward only)..." -ForegroundColor Cyan
        git pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            Fail "git pull --ff-only failed."
        }
        Write-Host "[DONE] Repository is up to date with remote." -ForegroundColor Green
    } else {
        Write-Host "[INFO] Local changes detected." -ForegroundColor Yellow
        Write-Host "[STEP] Staging changes (git add .)..." -ForegroundColor Cyan
        git add .
        if ($LASTEXITCODE -ne 0) {
            Fail "git add . failed."
        }

        if ([string]::IsNullOrWhiteSpace($Message)) {
            $Message = "Auto update $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        }

        Write-Host "[STEP] Committing with message: $Message" -ForegroundColor Cyan
        git commit -m "$Message"
        if ($LASTEXITCODE -ne 0) {
            Fail "git commit failed (possibly nothing to commit?)."
        }

        Write-Host "[STEP] Pulling latest changes with rebase..." -ForegroundColor Cyan
        git pull --rebase
        if ($LASTEXITCODE -ne 0) {
            Fail "git pull --rebase failed. Resolve conflicts and run again."
        }

        Write-Host "[STEP] Pushing to remote..." -ForegroundColor Cyan
        git push
        if ($LASTEXITCODE -ne 0) {
            Fail "git push failed."
        }

        Write-Host "[DONE] Local changes committed and pushed to remote." -ForegroundColor Green
    }
}
finally {
    Pop-Location
    Write-Host "[INFO] GitUpdate finished." -ForegroundColor Cyan
}
