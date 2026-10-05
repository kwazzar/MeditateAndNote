#!/usr/bin/env bash
# Opens one Xcode session per worktree. One session per worktree — see AGENTS.md.
set -euo pipefail

MAIN=/Users/nazar/Swift/MeditateAndNote
TASK=/Users/nazar/Swift/task2

for dir in "$MAIN" "$TASK"; do
    if [ ! -d "$dir" ]; then
        echo "skip: $dir missing (worktree not created?)" >&2
        continue
    fi
    open "$dir/MeditateAndNote.xcodeproj"
    echo "opened $dir"
done