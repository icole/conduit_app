# Staging Environment Setup Guide

This guide will help you set up the complete staging workflow for ConduitApp.

## Quick Start

If you're a new developer joining the project:

```bash
# 1. Clone the repository
git checkout -b staging origin/staging
cd conduit_app

# 2. Install dependencies and hooks
bin/setup

# 3. Verify git hooks are installed
lefthook run pre-commit  # Should run checks on staged files
```

That's it! You're ready to develop with automated quality checks.

## What Gets Installed

### 1. Pre-commit Hooks (Lefthook)

**Automatically runs before each commit:**
- **RuboCop**: Auto-fixes style issues
- **Brakeman**: Security vulnerability scanning
- **Migration check**: Warns about new database migrations

**To skip hooks (emergency only):**
```bash
LEFTHOOK=0 git commit -m "Emergency fix"
# OR
git commit --no-verify -m "Emergency fix"
```

### 2. Pre-push Hooks

**Automatically runs before git push:**
- **Full test suite**: Ensures all tests pass
- **Final security scan**: Brakeman check
- **Secrets detection**: Warns if secrets are exposed

## Creating the Staging Branch

If the `staging` branch doesn't exist yet, create it:

```bash
# From main branch
git checkout main
git pull origin main

# Create staging branch
git checkout -b staging
git push -u origin staging
```

## GitHub Secrets Setup

For automated staging deployments to work, configure these secrets in your GitHub repository:

**Settings → Secrets and variables → Actions → New repository secret**

### Required Secrets

```
# SSH Access
SSH_PRIVATE_KEY          # SSH private key for server access
SSH_KNOWN_HOSTS          # Server's SSH fingerprint

# Docker Registry
DOCKER_USERNAME          # Docker Hub username
DOCKER_PASSWORD          # Docker Hub password/token

# Rails
RAILS_MASTER_KEY         # From config/master.key
SECRET_KEY_BASE          # Generate with: rails secret

# Database
POSTGRES_PASSWORD        # PostgreSQL password for staging

# Google OAuth
GOOGLE_OAUTH_CLIENT_ID   # From Google Cloud Console
GOOGLE_OAUTH_CLIENT_SECRET
GOOGLE_CALENDAR_ID       # Google Calendar ID for events

# Stream Chat
STREAM_API_KEY           # From Stream.io dashboard
STREAM_API_SECRET

# Email (Staging SMTP)
SMTP_ADDRESS             # SMTP server address
SMTP_PORT                # SMTP port (usually 587)
SMTP_USERNAME            # SMTP username
SMTP_PASSWORD            # SMTP password
SMTP_DOMAIN              # Email domain
```

### Generating Secrets

```bash
# Generate SECRET_KEY_BASE
rails secret

# View RAILS_MASTER_KEY
cat config/master.key

# Generate SSH key pair (if needed)
ssh-keygen -t ed25519 -C "github-actions@conduitapp"
# Then add public key to server's ~/.ssh/authorized_keys

# Get SSH known hosts
ssh-keyscan conduit-staging.crowwoods.com
```

## Branch Protection Rules

### For `main` branch:

1. Go to **Settings → Branches → Branch protection rules**
2. Click **Add branch protection rule**
3. Configure:
   - Branch name pattern: `main`
   - ✅ Require a pull request before merging
   - ✅ Require approvals (1 minimum)
   - ✅ Require status checks to pass
   - ✅ Require branches to be up to date
   - ✅ Do not allow bypassing the above settings
   - Status checks that are required:
     - `scan_ruby`
     - `scan_js`
     - `lint`
     - `test`

### For `staging` branch:

1. Add another branch protection rule
2. Configure:
   - Branch name pattern: `staging`
   - ✅ Require status checks to pass
   - Status checks that are required:
     - `scan_ruby`
     - `scan_js`
     - `lint`
     - `test`
   - Note: Pull request NOT required (for faster iteration)

## GitHub Environments

Configure the `staging` environment for deployment tracking:

1. Go to **Settings → Environments**
2. Click **New environment**
3. Name: `staging`
4. Configure:
   - ✅ Required reviewers: (optional, for controlled staging deploys)
   - Environment secrets: (can override repository secrets if needed)
   - Deployment branches: Only `staging` branch

## Workflow

### Daily Development

```bash
# 1. Create feature branch from staging
git checkout staging
git pull origin staging
git checkout -b feature/my-feature

# 2. Develop with TDD
# Write test → Run test → Implement → Refactor

# 3. Commit (hooks run automatically)
git add .
git commit -m "Add feature X"
# → RuboCop auto-fixes code
# → Brakeman scans for security issues
# → Migration check warns if needed

# 4. Push to GitHub
git push -u origin feature/my-feature
# → Full test suite runs
# → Secrets detection runs

# 5. Create PR to staging
gh pr create --base staging --title "Add feature X"
```

### Staging Deployment

**Automatic:**
```bash
# Merge PR to staging
# → GitHub Actions automatically:
#    1. Runs CI (security, lint, tests)
#    2. Deploys to https://conduit-staging.crowwoods.com
#    3. Runs health checks
#    4. Sends notification
```

**Manual:**
```bash
# Deploy without merging to staging
bin/deploy-staging

# Verify deployment
bin/verify-staging
```

### Mobile App Testing

See full checklist in `STAGING_WORKFLOW.md`, but the key steps are:

1. **Trigger staging builds** (manual in Codemagic dashboard):
   - Run `android-staging` workflow
   - Run `ios-staging` workflow

2. **Test on devices**:
   - iOS: Install from TestFlight (alpha track)
   - Android: Install from Google Play (internal track)

3. **Run through mobile checklist**:
   - Authentication works
   - Core features work
   - Push notifications work
   - **Notification tap navigates to correct channel** ← Current feature

### Production Release

```bash
# 1. Ensure staging is fully tested
# 2. Create PR from staging → main
gh pr create --base main --head staging --title "Release: Feature X"

# 3. Get approval and merge
# → GitHub Actions deploys to production
# → Kamal deploys backend

# 4. Tag release for mobile app builds
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
# → Codemagic builds iOS and Android for app stores
```

## Troubleshooting

### Hooks not running

```bash
# Reinstall hooks
lefthook install

# Verify installation
lefthook run pre-commit
```

### Staging deployment failed

```bash
# Check deployment logs
# Go to GitHub Actions → Deploy to Staging → View logs

# Check server logs
kamal app logs -c config/deploy.staging.yml --follow

# Manual recovery
bin/deploy-staging

# Rollback if needed
kamal rollback -c config/deploy.staging.yml
```

### Tests failing in CI but passing locally

```bash
# Ensure you're testing against the same database
bin/rails db:test:prepare

# Run tests in CI mode
CI=true bin/rails test

# Check for environment-specific issues
RAILS_ENV=test bin/rails test
```

### Mobile builds failing

1. Check Codemagic build logs
2. Verify environment variables are set
3. Verify code signing certificates are valid
4. Check Xcode/Gradle versions match local environment

## Verification Commands

```bash
# Verify local setup
bundle exec lefthook run pre-commit    # Test hooks
bundle exec rubocop                     # Lint all files
bundle exec brakeman --no-pager         # Security scan
bundle exec rails test                  # Run all tests

# Verify staging deployment
bin/verify-staging                      # Run smoke tests
curl https://conduit-staging.crowwoods.com/up  # Health check

# Verify git hooks are working
git commit --allow-empty -m "Test"      # Should trigger hooks
```

## Resources

- **Full workflow documentation**: [STAGING_WORKFLOW.md](STAGING_WORKFLOW.md)
- **Deployment guide**: [DEPLOYMENT.md](DEPLOYMENT.md)
- **Development guidelines**: [CLAUDE.md](CLAUDE.md)
- **Project architecture**: [.claude-on-rails/context.md](.claude-on-rails/context.md)

## Quick Reference

| What | Command |
|------|---------|
| Install hooks | `bin/setup` or `lefthook install` |
| Test hooks | `lefthook run pre-commit` |
| Skip hooks | `LEFTHOOK=0 git commit` |
| Deploy staging | Auto on push to `staging` |
| Verify staging | `bin/verify-staging` |
| View logs | `kamal app logs -c config/deploy.staging.yml` |
| Rollback | `kamal rollback -c config/deploy.staging.yml` |
| Create PR | `gh pr create --base staging` |
| Release tag | `git tag -a v1.2.3 -m "..."` |

---

## Next Steps

After completing this setup:

1. ✅ Verify hooks are installed: `lefthook run pre-commit`
2. ✅ Create a test commit to see hooks in action
3. ✅ Review [STAGING_WORKFLOW.md](STAGING_WORKFLOW.md) for complete process
4. ✅ Set up GitHub secrets for automated deployments
5. ✅ Configure branch protection rules
6. ✅ Test a deployment to staging

**Questions?** Check [STAGING_WORKFLOW.md](STAGING_WORKFLOW.md) for detailed workflows, or ask the team.
