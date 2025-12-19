#!/bin/bash

# Safe PRs that passed CI
SAFE_PRS="54 53 52 45 40 39 31 27 22"

echo "=== Merging Safe PRs with Passing CI ==="
for pr in $SAFE_PRS; do
    echo "Merging PR #$pr..."
    gh pr merge $pr --merge --delete-branch
    echo ""
done

echo "=== Remaining Major Updates ==="
gh pr list --author "dependabot[bot]" --json number,title --jq '.[] | "PR #\(.number): \(.title)"'
