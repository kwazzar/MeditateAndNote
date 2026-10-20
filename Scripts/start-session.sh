#!/usr/bin/env bash
# Opens one Xcode session per worktree. One session per worktree — see AGENTS.md.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r dir; do
    proj="$dir/MeditateAndNote.xcodeproj"
    if [ ! -d "$proj" ]; then
        echo "skip: $proj missing" >&2
        continue
    fi
    open "$proj"
    echo "opened $proj"
done
