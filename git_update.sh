#!/usr/bin/env bash
set -euo pipefail

# ใช้แบบ:
#   ./git_update.sh                # ใช้ path ดีฟอลต์ + commit message auto
#   ./git_update.sh . "Update ps1" # ระบุ path + commit message เอง
#
# พารามิเตอร์:
#   $1 = path ของ repo (default: ~/OneDrive/Desktop/SetPowerSaver)
#   $2 = commit message (optional)

REPO_DIR="${1:-$HOME/OneDrive/Desktop/SetPowerSaver}"
COMMIT_MSG="${2:-}"

echo "[INFO] GitUpdate (WSL) starting..."
echo "[INFO] Repo dir: $REPO_DIR"

if [ ! -d "$REPO_DIR" ]; then
    echo "[ERROR] Repo directory not found: $REPO_DIR" >&2
    exit 1
fi

cd "$REPO_DIR"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "[ERROR] This is not a git repository: $REPO_DIR" >&2
    exit 1
fi

# ตรวจว่ามีการเปลี่ยนแปลงไหม
STATUS_OUTPUT="$(git status --porcelain)"

if [ -z "$STATUS_OUTPUT" ]; then
    echo "[INFO] No local changes detected."
    echo "[STEP] Pulling latest changes (fast-forward only)..."
    git pull --ff-only
    echo "[DONE] Repository is up to date with remote."
    exit 0
fi

echo "[INFO] Local changes detected:"
echo "$STATUS_OUTPUT"
echo "[STEP] Staging changes (git add .)..."
git add .

if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="Auto update $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo "[STEP] Committing with message: $COMMIT_MSG"
# ถ้าไม่มีอะไรให้ commit จริง ๆ git จะ exit 1 → เราจับแล้วแจ้ง แต่ไม่หยุดสคริปต์
if ! git commit -m "$COMMIT_MSG"; then
    echo "[WARN] git commit failed (possibly nothing to commit)."
fi

echo "[STEP] Pulling latest changes with rebase..."
git pull --rebase

echo "[STEP] Pushing to remote..."
git push

echo "[DONE] Local changes committed and pushed to remote."
