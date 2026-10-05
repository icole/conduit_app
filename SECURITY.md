# Security

## Reporting a vulnerability

Please email **ian@colecoding.com** rather than opening a public issue or pull
request. Include what you found, how to reproduce it, and what someone could
do with it. You'll get a reply within a few days, and a fix and a release as
soon as it's understood. Please give us a chance to fix it before you publish
details.

Testing against `api.conduitcoho.app` or a real community's address: use your
own account or community, don't access or change other people's data, and
don't run anything that degrades the service for others (load testing,
spamming signups or chat).

## Supported versions

Only the current deployment of the web app and the latest iOS and Android
builds get fixes.

## How Conduit keeps data safe

* **Communities are separate.** Every community's records are scoped to it
  (`acts_as_tenant`, with `require_tenant` in production); files, documents,
  chat (Stream Teams) and calendars are checked against the member's
  community, with tests that a member of one can't reach another's.
* **Accounts.** Joining a community needs an invitation, or founding one
  (which an admin approves). Email addresses are verified before chat and
  collaborative documents unlock. Passwords are bcrypt-hashed, at least 8
  characters. Sign-in and other sensitive endpoints are rate-limited.
* **The apps** use 30-day API tokens, revoked on sign-out, password change,
  account deletion and community suspension. Their web views sign in with a
  one-time code rather than putting the token in a URL. Chat tokens issued
  to current builds expire within the hour.
* **The web** uses an HTTP-only, `Secure`, `SameSite=Lax` session cookie,
  Rails' CSRF protection, HTTPS everywhere, and an enforced
  Content-Security-Policy whose violations are reported.
* **Checks on every change:** Brakeman (static analysis), bundler-audit
  (vulnerable gems), importmap audit (vulnerable JavaScript), and a test suite
  that refuses network access.
* **Backups** of the database and uploaded files are encrypted and taken
  nightly. Email delivery logs are deleted after 30 days.
