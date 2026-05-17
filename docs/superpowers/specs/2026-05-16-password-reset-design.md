# Password Reset Flow

## Overview

Token-based password reset allowing users to recover their account via email. The flow is entirely web-based (opened from mobile via browser). Admins can trigger the same reset email from the users list page.

## Flow

1. User taps "Forgot Password?" on mobile login screen (or visits web login)
2. Opens `{baseURL}/password_reset/new` in system browser
3. User enters email, submits
4. Server sends reset email via Resend (always shows success to prevent email enumeration)
5. User clicks link in email → `/password_reset/edit?token=xxx`
6. User enters new password + confirmation, submits
7. Password updated, redirected to login page

Admin flow: Admin clicks "Send Password Reset" on users list → triggers step 4 for that user.

## Server-Side Components

### Routes

```ruby
# Password reset (public)
get "password_reset/new", to: "password_resets#new"
post "password_reset", to: "password_resets#create"
get "password_reset/edit", to: "password_resets#edit"
patch "password_reset", to: "password_resets#update"

# Admin trigger
post "users/:id/send_password_reset", to: "users#send_password_reset", as: :send_password_reset_user
```

### PasswordResetsController

- Skips `authenticate_user!` on all actions
- `new` — renders email input form
- `create` — finds user by email, sends reset email, always shows generic success message
- `edit` — validates token, renders new-password form (or error if expired/invalid)
- `update` — validates token + password params, updates password, redirects to login

### Token Mechanism

Uses `JwtService` to generate a signed token containing:
- `user_id`
- `purpose: "password_reset"`
- `exp`: 1 hour from now
- `iat`: issued-at timestamp

Single-use enforcement: User model gets `password_reset_sent_at` column. Token is only valid if its `iat` >= `password_reset_sent_at`. After password is changed, `password_reset_sent_at` is cleared, invalidating any outstanding tokens.

### UserMailer

New mailer method `password_reset(user, token)`:
- Subject: "Reset your password"
- Body: brief message + reset link
- Uses existing ApplicationMailer (tenant-aware from address, Resend delivery)

### Migration

```ruby
add_column :users, :password_reset_sent_at, :datetime
```

## Web Pages

### `/password_reset/new`

- Standalone page (no app chrome/nav)
- Email input + "Send Reset Link" button
- Styled with Tailwind/DaisyUI consistent with login page
- On success: "If an account exists with that email, we've sent reset instructions."

### `/password_reset/edit?token=xxx`

- Standalone page
- New password + confirmation fields (min 6 chars)
- On success: "Password updated! You can now log in." with link to login
- On invalid/expired token: "This reset link has expired. Please request a new one." with link back to `/password_reset/new`

## Admin Trigger

### Users Index Page

Add a "Reset Password" button in the Actions column for each user (admin-only). Uses a `button_to` form that POSTs to `send_password_reset_user_path(user)`.

### UsersController#send_password_reset

- Requires admin
- Finds user, generates token, sends email
- Redirects back to users index with flash notice

## Mobile Changes

### iOS — `LoginViewController.swift`

Add a `UIButton` ("Forgot Password?") positioned below the password field, styled as a text link. On tap:

```swift
let url = URL(string: "\(AppConfig.baseURL)/password_reset/new")!
UIApplication.shared.open(url)
```

### Android — `activity_login.xml` + `LoginActivity.kt`

Add a `MaterialButton` (text style) with "Forgot Password?" between the password field and login button. On tap:

```kotlin
val url = "${AppConfig.getBaseUrl(this)}/password_reset/new"
startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
```

## Security

- Token expires in 1 hour
- Single-use via `password_reset_sent_at` timestamp comparison
- No email enumeration (always shows success message)
- HTTPS enforced on reset links via `default_url_options`
- Tenant-scoped: user lookup uses `ActsAsTenant.without_tenant` (same as login API)
- Reset page sets tenant from token's user before updating password

## Testing

- Model test: token generation + validation + expiry + single-use
- Controller tests: all 4 actions (happy path + invalid token + expired token)
- System test: full flow end-to-end
- Mailer test: email content + delivery
