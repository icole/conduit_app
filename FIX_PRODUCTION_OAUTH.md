# Fix Production Google OAuth Authentication

## Problem
Google OAuth login is failing in production with error:
```
invalid_client: Unauthorized
```

## Root Cause
The production environment (conduit.crowwoods.com) either:
1. Missing GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET environment variables
2. OAuth client not configured for production URL in Google Cloud Console

## Solution

### Step 1: Update Google Cloud Console

Go to: https://console.cloud.google.com/apis/credentials

Find your OAuth 2.0 Client (check .env file for GOOGLE_CLIENT_ID)

#### Add Production URLs:

**Authorized JavaScript origins:**
- `https://conduit.crowwoods.com`

**Authorized redirect URIs:**
- `https://conduit.crowwoods.com/auth/google_oauth2/callback`
- `https://conduit.crowwoods.com/auth:provider/callback` (if using dynamic providers)

Click **SAVE**

### Step 2: Set Production Environment Variables

#### If using Kamal for deployment:

1. Edit `.kamal/secrets` or your deployment configuration
2. Add:
```yaml
GOOGLE_CLIENT_ID: "your-client-id-from-env-file"
GOOGLE_CLIENT_SECRET: "your-client-secret-from-env-file"
```
(Use the actual values from your local .env file)

3. Redeploy:
```bash
kamal env push
kamal deploy
```

#### If using other deployment methods:

Set these environment variables in your production environment:
```bash
GOOGLE_CLIENT_ID=<your-client-id-from-env-file>
GOOGLE_CLIENT_SECRET=<your-client-secret-from-env-file>
```
(Use the actual values from your local .env file)

### Step 3: Add Failure Route (Optional but Recommended)

The logs show there's no route for `/auth/failure`. Add this to handle OAuth failures gracefully:

In `config/routes.rb`:
```ruby
get "/auth/failure", to: "sessions#auth_failure"
```

In `app/controllers/sessions_controller.rb`:
```ruby
def auth_failure
  message = params[:message] || "Authentication failed"
  redirect_to login_path, alert: "Authentication failed: #{message}"
end
```

### Step 4: Verify Configuration

After making changes, test:
1. Go to https://conduit.crowwoods.com/login
2. Click "Sign in with Google"
3. Should redirect to Google and back successfully

### Alternative: Create Production-Specific OAuth Client

If you want separate OAuth clients for dev/production:

1. Create new OAuth 2.0 Client in Google Cloud Console
2. Set it up specifically for production URLs
3. Use different environment variables:
   - Development: Current credentials
   - Production: New production-specific credentials

### Quick Diagnostic Commands

Check if environment variables are set in production:
```bash
# SSH into your server or container
echo $GOOGLE_CLIENT_ID
echo $GOOGLE_CLIENT_SECRET
```

Check Rails logs:
```bash
tail -f log/production.log | grep -E "oauth|google"
```

## Common Issues

1. **URLs must be HTTPS in production** - Google requires HTTPS for production OAuth
2. **Exact match required** - The redirect URI must match exactly (including trailing slashes)
3. **Changes take time** - Google OAuth changes can take 5-30 minutes to propagate
4. **Multiple environments** - Make sure you're editing the right OAuth client if you have multiple