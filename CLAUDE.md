# STOP - Read Before Any Code Change

1. **Write a failing test FIRST** — No exceptions. Test file before implementation file.
2. **Run the test, confirm it fails** — For the right reason, not syntax errors.
3. **Write minimum code to pass** — Then refactor if needed.
4. **Before committing:** `bin/rubocop && bin/rails test && bin/brakeman --no-pager`
5. **Don't push** — Batch commits locally. Ask before pushing to main.

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

Every push to `main` triggers Codemagic builds (iOS/Android). To save build minutes:
- Commit locally as you work
- Batch related changes
- Push once when feature is complete
