# Conduit

A Rails application for community coordination, with native iOS and Android apps.

## Features

* **Dashboard** - Community feed with posts, likes, and comments
* **Chat** - Real-time messaging powered by Stream Chat
* **Calendar** - Event scheduling with Google Calendar integration
* **Documents** - Shared documents with Google Drive integration
* **Chores** - Task management with assignments and completion tracking
* **Meals** - Community meal scheduling with cook signup and RSVPs
* **Decisions** - Community decision tracking
* **Discussion Topics** - Threaded discussions

## Multi-Community Support

Conduit supports multiple isolated communities, each with their own domain, users, and data. This is implemented using the `acts_as_tenant` gem for automatic query scoping.

### How It Works

- **Domain-based routing**: Each community has a configured domain. The community is determined by `request.host` (e.g., `conduit.crowwoods.com` routes to the "Crow Woods" community)
- **Data isolation**: All queries are automatically scoped to the current community. Users, posts, meals, chores, etc. from one community are never visible to another
- **Separate user accounts**: The same email can exist in different communities as completely separate accounts
- **Per-community settings**: Each community can have its own Google Calendar ID, Google Drive folder, and other settings stored in the `settings` JSONB column

### Community Model

```ruby
Community:
  - name          # Display name (e.g., "Crow Woods")
  - slug          # URL-friendly identifier (e.g., "crow-woods")
  - domain        # The domain for this community (e.g., "conduit.crowwoods.com")
  - settings      # JSONB for Google integration IDs, SMTP settings, etc.
  - time_zone     # Community's timezone (default: "America/New_York")
```

### Local Development

In development, the app automatically uses the "crow-woods" community when accessing via `localhost`. This means you don't need to set up custom domains locally.

**To create the initial community:**

```bash
# Run the data migration task (creates "Crow Woods" community and associates existing data)
bin/rails multi_community:setup
```

**To create additional communities:**

```ruby
# In rails console
Community.create!(
  name: "My Community",
  slug: "my-community",
  domain: "my-community.localhost",  # Or your production domain
  settings: {
    "google_calendar_id" => "your_calendar_id@group.calendar.google.com",
    "google_drive_folder_id" => "your_folder_id"
  }
)
```

**Testing with multiple communities locally:**

1. Add entries to `/etc/hosts`:
   ```
   127.0.0.1 community1.localhost
   127.0.0.1 community2.localhost
   ```

2. Create communities with those domains:
   ```ruby
   Community.create!(name: "Community 1", slug: "community-1", domain: "community1.localhost:3000")
   Community.create!(name: "Community 2", slug: "community-2", domain: "community2.localhost:3000")
   ```

3. Access each community at their respective URLs

### Background Jobs

Background jobs that process data across all communities (like meal reminders) automatically iterate over all communities:

```ruby
Community.find_each do |community|
  ActsAsTenant.with_tenant(community) do
    # All queries inside this block are scoped to this community
  end
end
```

## Setup

### Prerequisites

* Ruby 3.2.0 or higher
* PostgreSQL
* Node.js and Yarn

### Installation

1. Clone the repository
2. Run `bundle install` to install Ruby dependencies
3. Run `rails db:create db:migrate` to set up the database
4. Copy `.env.example` to `.env` and configure your environment variables
5. Start the server with `bin/dev`

## Environment Variables

Create a `.env` file with the following:

```
# Google OAuth (required for authentication)
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret

# Stream Chat (required for chat functionality)
STREAM_API_KEY=your_stream_api_key
STREAM_API_SECRET=your_stream_api_secret

# SMTP Email (required for email notifications)
SMTP_USERNAME=your_email_address
SMTP_PASSWORD=your_email_password

# JWT Secret (required for mobile app authentication)
JWT_SECRET=your_jwt_secret
```

## Google OAuth Setup

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to "APIs & Services" > "Credentials"
4. Click "Create Credentials" and select "OAuth client ID"
5. Select "Web application" as the application type
6. Add your callback URL to "Authorized redirect URIs":
   - Development: `http://localhost:3000/auth/google_oauth2/callback`
   - Production: `https://yourdomain.com/auth/google_oauth2/callback`
7. Save the client ID and secret to your `.env` file

## Stream Chat Setup

1. Create an account at [getstream.io](https://getstream.io/)
2. Create a new Chat application
3. Copy the API key and secret to your `.env` file
4. For push notifications:
   - **iOS**: Configure APN certificates in Stream Dashboard
   - **Android**: Upload Firebase service account JSON in Stream Dashboard

## Email Setup

Email notifications (meal reminders, RSVP confirmations, etc.) are sent via SMTP. The default configuration uses Namecheap PrivateEmail, but any SMTP provider works.

### Namecheap PrivateEmail (Default)

1. Use your domain email (e.g., `info@yourcommunity.com`)
2. Add to your `.env` file:
   ```
   SMTP_USERNAME=info@yourcommunity.com
   SMTP_PASSWORD=your_email_password
   ```

The SMTP server is configured as `mail.privateemail.com` on port 587.

### Other SMTP Providers

To use a different provider, update `config/initializers/email.rb` with your SMTP settings:

| Provider | Server | Port |
|----------|--------|------|
| Gmail | smtp.gmail.com | 587 |
| Outlook | smtp.office365.com | 587 |
| SendGrid | smtp.sendgrid.net | 587 |

**Note:** Gmail requires an [App Password](https://myaccount.google.com/apppasswords) (not your regular password).

## Mobile Apps

### iOS

The iOS app is located in the `ios/` directory. See `ios/README.md` for setup instructions.

### Android

The Android app is located in the `android/` directory.

#### Building

```bash
cd android
./gradlew assembleRelease
```

#### Configuration

Create `android/local.properties` with:

```properties
STREAM_API_KEY=your_stream_api_key
GOOGLE_CLIENT_ID=your_web_client_id
```

Note: The `GOOGLE_CLIENT_ID` should be your **Web** OAuth client ID (used for ID token verification).

For Google Sign-In, you'll also need to create Android OAuth clients in Google Cloud Console with your app's SHA-1 fingerprints.
