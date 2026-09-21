# Admin data Git scripts

## `push-export.sh`

Use after **Admin → Publish → Export** into a folder that is a clone of [Workout_v2_admin_data](https://github.com/pranith308/Workout_v2_admin_data) (often `Documents/WorkoutExport` on the phone).

The script **merges** `origin/main` before pushing so pushes succeed when GitHub already has commits you do not (e.g. from a Cursor agent or another device). Your new export commit is kept; remote changes are merged in, not discarded.

```bash
chmod +x push-export.sh
REPO_DIR="$HOME/storage/shared/Documents/WorkoutExport" ./push-export.sh -m "update"
```

## Publish vs Admin Data Update

| Step | Direction | What it does |
|------|-----------|--------------|
| **Admin Data Update** (Settings) | GitHub → app | Downloads `metadata.json` + JSON/media into the app database. Replaces Git-synced catalog rows. |
| **Publish → Export** | app → `WorkoutExport/` | Writes **full** current catalog from the app DB (exercises, templates, **meals/** ideas, **idea_categories/**, foods, recipes, media) into files. Not a delta. |
| **push-export.sh** | `WorkoutExport/` → GitHub | Commits file changes and pushes to `main`. |

After **Update → create new ideas → Publish**, the export folder should contain **everything** in the app catalog at that moment, including your new ideas under `meals/`. The Git repo on GitHub can still be **ahead in commit history** until you merge and push; that does not mean Publish skipped data.
