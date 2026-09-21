#!/usr/bin/env bash
# Push your Publish export folder to GitHub (Workout_v2_admin_data, branch main).
#
# 1. Commits any new export files
# 2. Merges origin/main into your current branch (so agent/other-device pushes are kept)
# 3. Pushes to main
#
# Usage on phone (Termux / export repo):
#   REPO_DIR="$HOME/storage/shared/Documents/WorkoutExport" sh push-export.sh -m "update"
#
# Or copy scripts/push-export.sh from this repo into WorkoutExport.

set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/storage/shared/Documents/WorkoutExport}"
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-main}"

msg="update"
while getopts "m:" opt; do
  case "$opt" in
    m) msg="$OPTARG" ;;
    *) echo "Usage: $0 [-m commit-message]"; exit 1 ;;
  esac
done

cd "$REPO_DIR" || { echo "❌ Repo not found: $REPO_DIR"; exit 1; }

git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ Not a git repo"; exit 1; }

echo "📡 Fetching $REMOTE/$BRANCH..."
git fetch "$REMOTE" "$BRANCH"

if [ -n "$(git status --porcelain)" ]; then
  echo "📦 Adding export files..."
  git add .
  echo "📝 Commit: $msg"
  git commit -m "$msg"
else
  echo "ℹ️ No uncommitted file changes (will still merge + push if ahead)."
fi

echo "🔀 Merging $REMOTE/$BRANCH (keeps GitHub history + your commits)..."
if ! git merge "$REMOTE/$BRANCH" -m "Merge remote $BRANCH before push"; then
  echo "❌ Merge conflict."
  echo "   Usually metadata.json or the same meal/exercise file changed on GitHub and in Publish."
  echo "   Open conflicted files, keep the content you want, then:"
  echo "     git add . && git commit && git push $REMOTE HEAD:$BRANCH"
  exit 1
fi

echo "🚀 Pushing..."
git push "$REMOTE" "HEAD:$BRANCH"

echo "✅ Done"
