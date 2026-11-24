#!/usr/bin/env bash
# Publish the phone export at Documents/WorkoutExport to GitHub main.
#
# The mapped drive cannot run git (it reports every file as deleted).
# This script copies the export into a local clone, then commits and pushes.
#
# Usage: bash scripts/push-export.sh
set -euo pipefail

git() { command git -c safe.directory='*' "$@"; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
if [ -d "$SCRIPT_DIR/../metadata.json" ] || [ -f "$SCRIPT_DIR/../metadata.json" ]; then
  SRC=$(cd "$SCRIPT_DIR/.." && pwd)
elif [ -n "${1:-}" ]; then
  SRC=$(cd "$1" && pwd)
else
  echo "Run this from the WorkoutExport/scripts folder." >&2
  exit 1
fi

LOCAL=$(cygpath -u "${LOCALAPPDATA:-$HOME/AppData/Local}")/Workout_v2_admin_data
ORIGIN="https://github.com/pranith308/Workout_v2_admin_data.git"

echo "Export: $SRC"
echo "Local repo: $LOCAL"

if [ ! -d "$LOCAL/.git" ]; then
  git clone "$ORIGIN" "$LOCAL"
fi

export SRC_WIN LOCAL_WIN
SRC_WIN=$(cygpath -w "$SRC")
LOCAL_WIN=$(cygpath -w "$LOCAL")

# Replace the local work tree with the export. Skip .git and MediaStore
# copies named like "file (1).json". Those copies match the real file.
powershell.exe -NoProfile -Command '
  $dst = $env:LOCAL_WIN
  $src = $env:SRC_WIN
  Get-ChildItem -Force -LiteralPath $dst | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
  robocopy $src $dst /E /XD .git /XF "* (*).*" /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
  if ($LASTEXITCODE -ge 8) { exit $LASTEXITCODE } else { exit 0 }
'
echo "Copied export into the local repo."

cd "$LOCAL"
if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  git checkout main
fi

if ! git config user.name >/dev/null || ! git config user.email >/dev/null; then
  echo "Set git user.name and user.email, then run this script again." >&2
  exit 1
fi

git add -A
if git diff --cached --quiet; then
  echo "No new export changes to commit."
else
  git commit -m "Publish admin export $(date '+%Y-%m-%d %H:%M')"
fi

integrate() {
  git fetch origin main
  set -- $(git rev-list --left-right --count HEAD...origin/main)
  ahead=$1
  behind=$2
  echo "Local commits not on GitHub: $ahead. GitHub commits not here: $behind."
  if [ "$behind" = "0" ]; then
    return 0
  fi
  echo "GitHub main moved. Rebasing your publish onto it."
  if git rebase origin/main; then
    return 0
  fi
  echo "Rebase conflict. Aborting the rebase and merging so both sides are kept."
  git rebase --abort
  if git merge origin/main --no-edit; then
    return 0
  fi
  echo "Merge conflict. Nothing was deleted. Your publish commit is still here." >&2
  git status --short >&2
  exit 1
}

integrate
if ! git push origin HEAD:main; then
  echo "Push was rejected because GitHub moved again. Integrating once more."
  integrate
  git push origin HEAD:main
fi

echo "Pushed. main is now $(git rev-parse --short HEAD)."