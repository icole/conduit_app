# STOP - Read Before Any Code Change

1. **Write a failing test FIRST** — No exceptions. Test file before implementation file.
2. **Run the test, confirm it fails** — For the right reason, not syntax errors.
3. **Write minimum code to pass** — Then refactor if needed.
4. **Before committing:** `bin/rubocop && bin/rails test && bin/brakeman --no-pager`
5. **Ask before pushing to main** — Batch commits locally; pushing is free (no auto-builds), but it's the user's call.

---

## Project Context

ConduitApp is a Rails application for cohousing community management. See @.claude-on-rails/context.md for full domain context and architecture details.

## Test Commands

```bash
bin/rails test                              # Run all tests
bin/rails test test/system/meals_test.rb   # Run specific file
bin/rails test test/system/meals_test.rb:42 # Run specific test
```

## Git Workflow

- Commit locally as you work; batch related changes
- Pushing to `main` does **not** trigger builds: the Codemagic iOS/Android workflows are manual, and only a `v*` tag triggers the App Store workflow (see `codemagic.yaml`)
- Server deploys are manual too: `. ./.env.deploy && bundle exec kamal deploy`
- Native builds are only needed when files under `ios/` or `android/` change — batch those; most server work ships without one
