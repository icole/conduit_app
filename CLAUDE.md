# STOP - Read Before Any Code Change

1. **Write a failing test FIRST** — No exceptions. Test file before implementation file.
2. **Run the test, confirm it fails** — For the right reason, not syntax errors.
3. **Write minimum code to pass** — Then refactor if needed.
4. **Before committing:** `bin/rubocop && bin/rails test && bin/brakeman --no-pager`
5. **Ask before pushing to main** — Batch commits locally. Web-only pushes are free, but a push touching `ios/` or `android/` starts a Codemagic build; either way it's the user's call.

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
- Pushing to `main` builds a native app only when that push changes `ios/` or `android/`: the matching Codemagic workflow builds it for TestFlight or Play closed testing. Web-only pushes build nothing. Store releases still need a `v*` tag (see `codemagic.yaml`)
- Server deploys are manual: `. ./.env.deploy && bin/deploy-preflight && bundle exec kamal deploy` — the preflight refuses to ship if any secret named in `.kamal/secrets` is empty in the shell (Kamal itself will silently deploy blanks)
- Native builds happen when files under `ios/` or `android/` change, so batch native changes into one push; most server work ships without one
