# Conduit Android App

Android version of the Conduit HOA app using Hotwire Native and Stream Chat.

## Features

- 🚀 Hotwire Native for Android - Native navigation with web content
- 💬 Stream Chat SDK integration
- 🔐 Google Sign-In authentication
- 🔔 Push notifications via FCM
- 🏠 Tab navigation (Home, Chat, Profile)

## Requirements

- Android Studio Arctic Fox or later
- Android SDK 24+ (Android 7.0)
- Java 11 or Kotlin 1.7+
- Firebase project for push notifications

## Setup

### 1. Clone and Open Project

```bash
cd android
# Open in Android Studio
```

### 2. Configure Base URL

Create `app/src/main/res/values/config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- For debug builds (local development) -->
    <string name="base_url_debug">http://10.0.2.2:3000</string>

    <!-- For release builds (production) -->
    <string name="base_url_release">https://conduit.crowwoods.com</string>
</resources>
```

### 3. Add Google Services

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create/select your project
3. Add Android app with package: `com.colecoding.conduit`
4. Download `google-services.json`
5. Place in `app/` directory

### 4. Configure Stream Chat

Add your Stream API key in `config.xml`:

```xml
<string name="stream_api_key">psybsap3ftmn</string>
```

### 5. Build and Run

```bash
# Debug build (uses local server)
./gradlew assembleDebug

# Release build (uses production server)
./gradlew assembleRelease
```

## Project Structure

```
android/
├── app/
│   ├── src/
│   │   └── main/
│   │       ├── java/com.colecoding.conduit/
│   │       │   ├── MainActivity.kt          # Main Hotwire activity
│   │       │   ├── MainApplication.kt       # Application class
│   │       │   ├── auth/
│   │       │   │   └── LoginActivity.kt     # Native login screen
│   │       │   ├── chat/
│   │       │   │   └── StreamChatActivity.kt # Stream Chat UI
│   │       │   ├── config/
│   │       │   │   └── AppConfig.kt         # Configuration
│   │       │   └── navigation/
│   │       │       └── Navigator.kt         # Hotwire navigation
│   │       └── res/
│   │           ├── layout/                  # UI layouts
│   │           ├── values/                  # Strings, configs
│   │           └── xml/                     # Network security
│   └── google-services.json                 # Firebase config
└── gradle/                                   # Build configuration
```

## Development

### Debug Mode
- Uses `http://10.0.2.2:3000` (Android emulator localhost)
- Development push tokens
- Console logging enabled

### Release Mode
- Uses production URL from config
- Production push tokens
- ProGuard enabled

## Push Notifications

### Setup FCM

1. Notifications are handled via Firebase Cloud Messaging
2. Token is registered with Stream Chat on login
3. Configure FCM server key in Stream Dashboard

### Testing

1. Install app on device/emulator
2. Grant notification permissions
3. Log in to the app
4. Send message from another user
5. Notification should appear

## Troubleshooting

### Common Issues

**Network Security:**
For local development, network security config allows cleartext:
- See `app/src/main/res/xml/network_security_config.xml`

**Stream Chat Connection:**
- Check API key in config.xml
- Verify user authentication token from Rails
- Check Stream Dashboard for errors

**Push Notifications:**
- Ensure google-services.json is present
- Check FCM token registration in logs
- Verify Stream Dashboard has FCM server key

## Links

- [Hotwire Native Android Docs](https://github.com/hotwired/hotwire-native-android)
- [Stream Chat Android SDK](https://getstream.io/chat/docs/sdk/android/)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)