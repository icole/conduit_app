#!/bin/bash

# Minor and patch updates that can be auto-merged
SAFE_PRS="54 53 52 45 40 39 31 27 22"

# Major updates that need manual review
MAJOR_PRS="51 49 43"

echo "=== Handling Safe PRs (Minor/Patch updates) ==="
for pr in $SAFE_PRS; do
    echo "Processing PR #$pr..."
    # Approve the PR
    gh pr review $pr --approve --body "Auto-approved: Minor/Patch version update"
    # Enable auto-merge
    gh pr merge $pr --auto --merge
    echo "PR #$pr: Approved and auto-merge enabled"
    echo ""
done

echo "=== Major Updates (Manual review required) ==="
for pr in $MAJOR_PRS; do
    title=$(gh pr view $pr --json title --jq '.title')
    echo "PR #$pr: $title"
    echo "  → Requires manual review (major version change)"
done
