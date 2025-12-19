#!/bin/bash

# Close conflicted PRs with a comment asking Dependabot to recreate
CONFLICTED_PRS="45 40 39 31 27 22"

echo "=== Closing conflicted PRs for recreation ==="
for pr in $CONFLICTED_PRS; do
    title=$(gh pr view $pr --json title --jq '.title')
    echo "PR #$pr: $title"
    # Close with comment
    gh pr close $pr --comment "@dependabot recreate"
    echo "  → Closed and requested recreation"
done

echo ""
echo "Dependabot will recreate these PRs with resolved conflicts shortly."
echo "The new PRs will be automatically approved and merged by your workflow!"
