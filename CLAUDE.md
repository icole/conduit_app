## ClaudeOnRails Configuration

You are working on ConduitApp, a Rails application. Review the ClaudeOnRails context file at
@.claude-on-rails/context.md

## Pre-Commit Requirements

Before committing any code changes, ALWAYS run these checks and fix any issues:

1. **RuboCop** (linting): `bin/rubocop`
2. **Tests**: `bin/rails test`
3. **Brakeman** (security): `bin/brakeman --no-pager`

All three must pass before creating a commit. Fix any errors or warnings before proceeding.

## Git Workflow

**Important: Batch commits before pushing to save CI/CD build minutes.**

Every push to `main` triggers Codemagic builds for iOS and Android, which uses build minutes. To minimize unnecessary builds:

1. **Commit locally** as you complete changes
2. **Don't push immediately** after each commit
3. **Batch related changes** into logical chunks before pushing
4. **Ask before pushing** or wait for explicit confirmation to push
5. **Push once** when a complete feature or fix is ready

This ensures we only trigger builds when there's meaningful work to test.
