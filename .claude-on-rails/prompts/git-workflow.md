# Git Workflow Instructions

## Git Commit Policy

**IMPORTANT: Do not commit changes without explicit user approval.**

When making code changes:

✅ **DO:**
- Make the necessary code changes
- Run tests to verify functionality
- Stage changes with `git add`
- Show the user what changes were made
- Wait for user review and approval

❌ **DO NOT:**
- Run `git commit` without explicit user permission
- Run `git push` without explicit user permission
- Auto-commit fixes or improvements

## Workflow Process

1. **Make Changes**: Implement the requested feature/fix
2. **Test Changes**: Ensure tests pass and functionality works
3. **Run Rubocop**: Always run `rubocop -f github -A` to auto-fix linting issues
4. **Stage Changes**: Use `git add` to stage the changes (including rubocop fixes)
5. **Present Changes**: Show user what was changed and ask for review
6. **Wait for Approval**: Let user review before any commits
7. **User Commits**: User decides when and how to commit

## Code Quality Requirements

- **Always run Rubocop**: Use `rubocop -f github -A` to auto-fix style issues
- **Conform to Ruby Style Guide**: Follow the project's Rubocop configuration
- **No lint errors**: Code should pass all Rubocop checks before staging

This ensures full control over the codebase, deployment timing, and code quality.