# Staging Workflow & Release Process

This document outlines the complete staging and release process for ConduitApp, including backend (Rails), iOS, and Android components.

## Table of Contents

1. [Git Branching Strategy](#git-branching-strategy)
2. [Development Workflow](#development-workflow)
3. [Staging Process](#staging-process)
4. [Mobile App Testing](#mobile-app-testing)
5. [Production Release](#production-release)
6. [Emergency Hotfixes](#emergency-hotfixes)

---

## Git Branching Strategy

### Branch Types

```
main                    # Production-ready code (triggers production builds)
  ↑
staging                 # Integration testing (triggers staging deployment)
  ↑
feature/xyz            # Feature branches
claude/xyz             # AI-assisted feature branches
hotfix/xyz             # Emergency fixes
```

### Branch Protection Rules

**`main` branch:**
- Requires pull request reviews (1 approver minimum)
- Requires status checks to pass (CI, tests, linting)
- Requires branches to be up to date before merging
- No direct commits allowed
- Triggers Codemagic builds for iOS and Android (production)
- Triggers Kamal production deployment

**`staging` branch:**
- Requires status checks to pass (CI, tests, linting)
- Pull request recommended but not required for speed
- Triggers automated staging deployment
- Triggers Codemagic builds for iOS and Android (staging/TestFlight alpha)

**Feature branches:**
- No restrictions
- Must pass CI before merge to staging
- Naming: `feature/description` or `claude/description-XXXXX`

---

## Development Workflow

### 1. Create Feature Branch

```bash
# From staging branch
git checkout staging
git pull origin staging
git checkout -b feature/notification-navigation

# Or let Claude create it
git checkout -b claude/notification-navigation-$(openssl rand -hex 3)
```

### 2. Develop with TDD

Follow the TDD process outlined in `CLAUDE.md`:

1. Write a failing test first
2. Run the test to confirm it fails
3. Implement minimum code to pass
4. Refactor while keeping tests green
5. Run all tests to ensure no regressions

### 3. Pre-Commit Validation (Automated)

When you commit, Lefthook automatically runs:

- **RuboCop** - Linting (auto-fix when possible)
- **Brakeman** - Security scanning
- **Tests** - Related test files
- **Migrations check** - Warns if migrations need review

If any check fails, the commit is blocked until fixed.

### 4. Push and Create PR

```bash
# Push feature branch
git push -u origin feature/notification-navigation

# Create pull request to staging
gh pr create --base staging --title "Add notification navigation" --body "..."
```

---

## Staging Process

### Phase 1: Automated Deployment

**When:** Push to `staging` branch (or merge feature PR to staging)

**What Happens:**

1. **GitHub Actions CI** runs:
   - Brakeman security scan
   - RuboCop linting
   - Full test suite with PostgreSQL
   - JavaScript dependency audit
   - System tests with screenshot capture

2. **If CI passes**, GitHub Actions triggers:
   - Kamal deployment to `conduit-staging.crowwoods.com`
   - Database migrations (if any)
   - Asset precompilation
   - Health check validation
   - Slack notification with deployment status

3. **If deployment succeeds**:
   - Staging environment is updated
   - Post-deployment smoke tests run
   - Success notification sent to team

**Manual trigger (if needed):**
```bash
bin/deploy-staging
```

### Phase 2: Backend Testing

**Who:** Developer or QA tester

**Staging Environment:**
- URL: `https://conduit-staging.crowwoods.com`
- Database: Staging PostgreSQL with test data
- Email: SMTP (emails sent to broader allowlist)
- Stream Chat: Staging API key
- Google OAuth: Staging credentials

**Testing Checklist:**

- [ ] Web UI navigation works
- [ ] User authentication (Google OAuth)
- [ ] Core features work (meals, tasks, chat)
- [ ] Database migrations applied successfully
- [ ] New feature works as expected
- [ ] No console errors or warnings
- [ ] API endpoints respond correctly
- [ ] Background jobs process successfully

**Health Check URL:**
```
https://conduit-staging.crowwoods.com/up
```

### Phase 3: Mobile App Testing

#### Trigger Staging Builds

Staging builds are triggered **manually** via Codemagic to save build minutes.

**When to trigger:**
- Major feature changes affecting mobile
- API changes that impact mobile clients
- Before merging to main

**How to trigger:**

1. Go to Codemagic dashboard
2. Select `conduit_app` project
3. Run `android-staging` workflow (deploys to Google Play internal track)
4. Run `ios-staging` workflow (deploys to TestFlight alpha)
5. Wait 15-30 minutes for builds to complete

#### iOS Testing (TestFlight Alpha)

**Testers:**
- Internal testers via TestFlight
- Must have TestFlight app installed

**Testing Process:**

1. Wait for TestFlight email notification
2. Install staging build from TestFlight
3. Run through mobile testing checklist (see below)
4. Report any issues in GitHub

**Staging App Identifier:**
- Bundle ID: `com.colecoding.conduit.staging` (or same with staging build)
- Different badge/icon to distinguish from production

#### Android Testing (Google Play Internal Track)

**Testers:**
- Internal testers via Google Play internal track
- Must be added as internal testers in Google Play Console

**Testing Process:**

1. Check Google Play Console for new internal release
2. Install from Play Store (internal track)
3. Run through mobile testing checklist (see below)
4. Report any issues in GitHub

**Staging App Identifier:**
- Package: `com.colecoding.conduit.staging` (or same with staging build)
- Different badge/icon to distinguish from production

#### Mobile Testing Checklist

**Authentication & Setup:**
- [ ] App launches without crashes
- [ ] Community selection works
- [ ] Google OAuth login works
- [ ] Session persists after app restart
- [ ] Logout and re-login works

**Core Features:**
- [ ] Home tab loads and displays posts
- [ ] Tasks tab shows tasks list
- [ ] Meals tab shows upcoming meals
- [ ] Chat tab connects to Stream
- [ ] Account tab shows user profile

**Chat Features (Primary Focus):**
- [ ] Channel list loads
- [ ] Can open existing channels
- [ ] Can send messages
- [ ] Messages appear in real-time
- [ ] **Push notifications received when app backgrounded**
- [ ] **Tapping notification opens app to correct channel**
- [ ] **Notification badge shows unread count**
- [ ] Can create new channels (if applicable)
- [ ] Channel muting works
- [ ] Can leave channels

**Navigation:**
- [ ] Tab switching works smoothly
- [ ] Back navigation works correctly
- [ ] Deep links work (if applicable)
- [ ] No memory leaks or freezes

**Specific Feature Testing (Current PR):**
- [ ] Notification tap navigates to specific channel
- [ ] Works from cold start (app not running)
- [ ] Works from background (app running)
- [ ] Channel opens with correct message context
- [ ] No crashes when notification data is missing

**Performance:**
- [ ] App responds quickly to user actions
- [ ] No ANR (Android) or hangs (iOS)
- [ ] Smooth scrolling in lists
- [ ] Images load properly

**Error Cases:**
- [ ] Network errors handled gracefully
- [ ] Invalid data doesn't crash app
- [ ] Error messages are user-friendly

### Phase 4: Sign-Off

Before merging to `main`, ensure:

**Backend:**
- [ ] All staging tests passed
- [ ] No errors in production logs (Sentry staging if configured)
- [ ] Performance acceptable (response times, database queries)
- [ ] Database migrations tested

**Mobile (if applicable):**
- [ ] iOS staging build tested on physical device
- [ ] Android staging build tested on physical device
- [ ] Critical user flows work end-to-end
- [ ] No crashes or major bugs

**Documentation:**
- [ ] CHANGELOG updated with changes
- [ ] README updated if needed
- [ ] Migration notes added if applicable

---

## Production Release

### Step 1: Merge Staging to Main

```bash
# Ensure staging is fully tested
git checkout staging
git pull origin staging

# Create PR from staging to main
gh pr create --base main --head staging \
  --title "Release: [Feature Name]" \
  --body "## Changes
- Feature 1
- Feature 2

## Testing
- [x] Staging backend tested
- [x] iOS staging build tested
- [x] Android staging build tested

## Database Migrations
- [ ] None
- [ ] Yes - [describe migrations]
"

# Get approval and merge
```

### Step 2: Automatic Backend Deployment

**Triggered by:** Merge to `main`

**What happens:**
1. GitHub Actions CI runs (same as staging)
2. Kamal deploys to production (`conduit.crowwoods.com`)
3. Database migrations run
4. Health checks validate deployment
5. Slack notification sent

### Step 3: Mobile App Release

**Triggered by:** Version tag OR manual trigger

#### Option A: Automatic (Recommended)

```bash
# Tag a release version
git tag -a v1.2.3 -m "Release v1.2.3: Notification navigation"
git push origin v1.2.3

# Codemagic "release" workflow triggers automatically
# - Builds iOS and Android
# - Increments version codes
# - Submits to App Store and Google Play
```

#### Option B: Manual

1. Go to Codemagic dashboard
2. Run `android-production` workflow (Google Play production track)
3. Run `ios-production` workflow (App Store submission)
4. Wait for app store review (iOS: 1-3 days, Android: few hours)

### Step 4: Monitor Production

**Immediately after deployment:**

- [ ] Check health endpoint: `https://conduit.crowwoods.com/up`
- [ ] Monitor Sentry for errors (first 15 minutes)
- [ ] Check application logs in Kamal
- [ ] Verify critical user flows work
- [ ] Monitor database performance

**First 24 hours:**

- [ ] Review Sentry error reports
- [ ] Check user feedback/support tickets
- [ ] Monitor performance metrics
- [ ] Review background job success rates

**Commands:**

```bash
# View application logs
kamal app logs --follow

# Check running containers
kamal app details

# View database status
kamal accessory logs postgres

# Rollback if needed (see Emergency Hotfixes)
kamal rollback
```

---

## Emergency Hotfixes

### When to Use

- Critical production bug affecting users
- Security vulnerability
- Data corruption issue
- Service outage

### Hotfix Process

```bash
# 1. Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug-fix

# 2. Develop and test fix
# - Write test that reproduces bug
# - Fix the bug
# - Ensure test passes
# - Run full test suite

# 3. Deploy to staging first (validate fix)
git checkout staging
git merge hotfix/critical-bug-fix
git push origin staging
# Wait for staging deployment and test

# 4. Merge to main (fast-track)
git checkout main
git merge hotfix/critical-bug-fix
git push origin main

# 5. Tag as hotfix release
git tag -a v1.2.4 -m "Hotfix: Critical bug fix"
git push origin v1.2.4

# 6. Merge back to staging to keep in sync
git checkout staging
git merge main
git push origin staging
```

**Note:** Hotfixes skip normal review process but should still:
- Pass all automated tests
- Be tested in staging first (even if briefly)
- Have PR created for documentation (can merge immediately)

---

## Build Minute Conservation Strategy

### Problem

- Every push to `main` triggers Codemagic iOS + Android builds
- Builds use CI/CD build minutes (limited per month)
- Unnecessary builds waste resources

### Solution: Batching and Manual Triggers

**Backend-only changes:**
- Do NOT trigger mobile builds
- Batch multiple backend changes before mobile release
- Only trigger mobile builds when needed

**How to batch:**

1. Make multiple backend changes
2. Merge each to `staging` and test
3. When ready for production:
   - Merge staging to main
   - **Skip automatic mobile builds** (configure Codemagic to manual-only)
   - Manually trigger mobile builds when accumulated changes warrant update

**Mobile build triggers:**

```yaml
# codemagic.yaml - manual trigger recommended
workflows:
  android-production:
    # Only trigger on manual start or version tags
    triggering:
      events:
        - tag
      tag_patterns:
        - pattern: 'v*'
      manual: true  # Enable manual triggering
```

**When to trigger mobile builds:**

- New mobile features
- Bug fixes affecting mobile
- API changes impacting mobile
- Monthly updates (even without changes, for security updates)

---

## Summary Diagram

```
┌─────────────────┐
│ Feature Branch  │
└────────┬────────┘
         │ PR + CI
         ↓
┌─────────────────┐
│    Staging      │ ← Auto-deploy on merge
└────────┬────────┘
         │ Test: Backend + Mobile (manual builds)
         │ Sign-off required
         ↓
┌─────────────────┐
│      Main       │ ← Auto-deploy backend
└────────┬────────┘
         │ Tag version (v*)
         ↓
┌─────────────────┐
│   Production    │ ← Mobile builds triggered by tag
│  (App Stores)   │
└─────────────────┘
```

## Key Principles

1. **Never push directly to main** - Always go through staging
2. **Test in staging first** - Backend and mobile testing required
3. **Batch commits** - Reduce unnecessary CI builds
4. **Manual mobile builds in staging** - Save build minutes
5. **Automate what's repeatable** - CI, deployments, health checks
6. **Document everything** - PRs, changelogs, migration notes
7. **Monitor after release** - First 24 hours are critical

---

## Quick Reference

| Task | Command |
|------|---------|
| Create feature branch | `git checkout -b feature/name` |
| Deploy to staging | Auto on push to `staging` |
| Test staging backend | Visit `https://conduit-staging.crowwoods.com` |
| Trigger staging mobile builds | Manual in Codemagic dashboard |
| Merge to production | PR from `staging` to `main` |
| Release mobile apps | `git tag v1.2.3 && git push origin v1.2.3` |
| View production logs | `kamal app logs --follow` |
| Rollback deployment | `kamal rollback` |
| Health check | `curl https://conduit.crowwoods.com/up` |

## Next Steps

See implementation tasks in repository issues:
- [ ] Set up pre-commit hooks (Lefthook)
- [ ] Create GitHub Action for automated staging deployment
- [ ] Add post-deployment smoke tests
- [ ] Configure Codemagic for staging builds
- [ ] Set up Slack notifications
- [ ] Create staging branch protection rules
