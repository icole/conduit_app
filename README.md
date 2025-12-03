# Conduit

A Rails application for community coordination, with native iOS and Android apps.

## Features

* **Dashboard** - Community feed with posts, likes, and comments
* **Chat** - Real-time messaging powered by Stream Chat
* **Calendar** - Event scheduling with Google Calendar integration
* **Documents** - Shared documents with Google Drive integration
* **Chores** - Task management with assignments and completion tracking
* **Decisions** - Community decision tracking
* **Discussion Topics** - Threaded discussions

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
