## ClaudeOnRails Configuration

You are working on ConduitApp, a Rails application. Review the ClaudeOnRails context file at
@.claude-on-rails/context.md

## Pre-Commit Requirements

Before committing any code changes, ALWAYS run these checks and fix any issues:

1. **RuboCop** (linting): `bin/rubocop`
2. **Tests**: `bin/rails test`
3. **Brakeman** (security): `bin/brakeman --no-pager`

All three must pass before creating a commit. Fix any errors or warnings before proceeding.
