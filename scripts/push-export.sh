#!/bin/sh
# Termux "sh" does not support pipefail. Hand off to bash, then continue.
if [ -z "${BASH_VERSION:-}" ]; then
  if command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  fi
  echo "This script needs bash. In Termux run: pkg install bash" >&2
  exit 1
fi

set -euo pipefail

# Publish Documents/WorkoutExport to GitHub main.
# Phone (Termux): bash scripts/push-export.sh
# Windows Git Bash: same command. The mapped drive cannot host .git, so
# Windows copies the export into a local clone first.
git() { command git -c safe.directory='*' "$@"; }

ORIGIN="https://github.com/pranith308/Workout_v2_admin_data.git"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
if [ -f "$SCRIPT_DIR/../metadata.json" ]; then
  SRC=$(cd "$SCRIPT_DIR/.." && pwd)
elif [ -n "${1:-}" ]; then
  SRC=$(cd "$1" && pwd)
else
  echo "Run this from WorkoutExport/scripts, or pass the WorkoutExport path." >&2
  exit 1
fi

drop_numbered_copies() {
  # MediaStore duplicates: "file (1).ext". Keep names like "squat_(Quad).gif".
  local root="$1"
  find "$root" \( -path '*/.git' -o -path '*/.git/*' \) -prune -o -type f -name '* (*).*' -print0 |
    while IFS= read -r -d '' file; do
      case "$(basename "$file")" in
        *' ('[0-9]')'.*|*' ('[0-9][0-9]')'.*) rm -f "$file" ;;
      esac
    done
}

commit_and_push() {
  if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
    git checkout main
  fi

  if ! git config user.name >/dev/null || ! git config user.email >/dev/null; then
    echo "Set your name once, then run this script again:" >&2
    echo "  git config --global user.name \"Your Name\"" >&2
    echo "  git config --global user.email \"you@example.com\"" >&2
    exit 1
  fi

  git add -A
  if git diff --cached --quiet; then
    echo "No new export changes to commit."
  else
    git commit --trailer "Co-authored-by: Cursor <cursoragent@cursor.com>" -m "Publish admin export $(date '+%Y-%m-%d %H:%M')"
  fi

  integrate
  if ! git push origin HEAD:main; then
    echo "Push was rejected because GitHub moved again. Integrating once more."
    integrate
    git push origin HEAD:main
  fi
  echo "Pushed. main is now $(git rev-parse --short HEAD)."
}

integrate() {
  git fetch origin main
  set -- $(git rev-list --left-right --count HEAD...origin/main)
  local ahead="$1"
  local behind="$2"
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

publish_phone() {
  if ! command -v git >/dev/null 2>&1; then
    echo "Install git first: pkg install git" >&2
    exit 1
  fi
  cd "$SRC"
  echo "Publishing from the phone: $SRC"
  if [ ! -d .git ]; then
    echo "First run: attaching GitHub history. Your export files stay in place."
    local tmp
    tmp=$(mktemp -d)
    git clone --no-checkout "$ORIGIN" "$tmp/clone"
    mv "$tmp/clone/.git" .git
    rm -rf "$tmp"
    git reset -q
  fi
  drop_numbered_copies "$SRC"
  commit_and_push
}

publish_windows() {
  local local_repo src_win local_win
  local_repo="$(cygpath -u "${LOCALAPPDATA:-$HOME/AppData/Local}")/Workout_v2_admin_data"
  echo "Export: $SRC"
  echo "Local repo: $local_repo"
  if [ ! -d "$local_repo/.git" ]; then
    git clone "$ORIGIN" "$local_repo"
  fi
  src_win=$(cygpath -w "$SRC")
  local_win=$(cygpath -w "$local_repo")
  SRC_WIN="$src_win" LOCAL_WIN="$local_win" powershell.exe -NoProfile -Command '
    $dst = $env:LOCAL_WIN
    $src = $env:SRC_WIN
    Get-ChildItem -Force -LiteralPath $dst | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
    robocopy $src $dst /E /XD .git /XF "* (*).*" /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    if ($LASTEXITCODE -ge 8) { exit $LASTEXITCODE } else { exit 0 }
  '
  echo "Copied export into the local repo."
  cd "$local_repo"
  commit_and_push
}

if command -v cygpath >/dev/null 2>&1 && command -v powershell.exe >/dev/null 2>&1; then
  publish_windows
else
  publish_phone
fi