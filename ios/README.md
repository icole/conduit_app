# Conduit iOS App

This is the iOS Hotwire Native app for the Conduit HOA management system.

## Features

- **Native Authentication**: iOS-native login screen with email/password and Google Sign-In
- **Tab Navigation**: Three tabs - Home (main app), Chat (Stream Chat), and Profile
- **Hotwire Native**: Full Rails app functionality in a native iOS shell
- **Stream Chat Integration**: Native iOS SDK for real-time community messaging
- **Secure Session Management**: Cookie synchronization between native and web contexts

## Requirements

- Xcode 14.0+
- iOS 15.0+
- Swift 5.7+

## Setup Instructions

### 1. Configure Google Sign-In (REQUIRED)

The `GoogleService-Info.plist` file contains sensitive API keys and is NOT committed to version control. You must set this up:

a. Copy the template file:
```bash
cp Conduit/Conduit/GoogleService-Info.plist.template Conduit/Conduit/GoogleService-Info.plist
```

b. Obtain your Google OAuth credentials:
- Go to [Google Cloud Console](https://console.cloud.google.com)
- Create or select your project
- Enable the Google Sign-In API
- Create OAuth 2.0 credentials for iOS
- Download the `GoogleService-Info.plist`

c. Replace the template values in your local `GoogleService-Info.plist` with your actual credentials

### 2. Configure Production URL (Optional)

For production deployment, copy and configure:
```bash
cp Conduit/Conduit/Config.plist.template Conduit/Conduit/Config.plist
```
Edit `Config.plist` with your production URL. See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for details.

### 3. Install Dependencies

```bash
cd ios/Conduit
swift package resolve
```

### 4. Open in Xcode

```bash
open Conduit.xcodeproj
```

Or create a new Xcode project:
1. Open Xcode
2. File → New → Project
3. Choose "App" template
4. Product Name: Conduit
5. Team: Your development team
6. Organization Identifier: com.yourorganization
7. Interface: UIKit
8. Language: Swift
9. Use Core Data: No
10. Include Tests: Yes (optional)

### 3. Add Swift Package Dependencies

In Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/hotwired/hotwire-native-ios`
3. Version: Up to Next Major Version: 1.0.0
4. Add Package

### 4. Configure the Project

1. Delete the default `ViewController.swift` and `Main.storyboard`
2. Copy all the Swift files from this directory into your Xcode project
3. Update `Info.plist` with the provided configuration
4. In Project Settings → Info → Custom iOS Target Properties:
   - Remove "Main storyboard file base name" entry

### 5. Update URLs

Edit `TabBarController.swift`:
- For development: `http://localhost:3000`
- For production: Replace with your production URL

### 6. Build and Run

1. Select your target device or simulator
2. Press ⌘R or click the Run button

## Development

### Local Rails Server

Make sure your Rails server is running:
```bash
cd ../.. # Back to Rails root
bin/rails server
```

### Testing on Physical Device

For testing on a physical device with localhost:
1. Ensure your device and Mac are on the same network
2. Replace `localhost` with your Mac's IP address in `TabBarController.swift`
3. Or use a service like ngrok to create a public tunnel

## Architecture

```
Conduit/
├── AppDelegate.swift           # App lifecycle and configuration
├── SceneDelegate.swift         # Scene management and window setup
├── TabBarController.swift      # Main tab bar with Home and Chat tabs
├── Navigator.swift             # Hotwire Native navigation controller
├── HotwireNativeViewController.swift  # Base view controller for web views
├── ChatViewController.swift    # Specialized controller for Element Web
├── Package.swift              # Swift Package Manager configuration
└── Info.plist                 # App configuration and permissions
```

## Features

### Tab Bar Navigation
- **Home Tab**: Main Rails application
- **Chat Tab**: Element Web (Matrix chat client)

### Hotwire Native Integration
- Full Rails app functionality
- Native navigation and transitions
- Pull to refresh support
- Authentication handling

### Element Web Integration
- Full-screen chat experience
- Camera/microphone permissions for future video calls
- Secure Matrix messaging

## Security Notes

⚠️ **IMPORTANT**: Never commit `GoogleService-Info.plist` to version control as it contains sensitive API keys.

For production apps:
1. **Restrict API key usage in Google Cloud Console:**
   - Add iOS app bundle ID restrictions
   - Limit to specific APIs only
   - Set up quota limits and alerts

2. **Use environment-specific configurations** for different API keys (development/staging/production)

## Troubleshooting

### Google Sign-In Not Working
- Verify `GoogleService-Info.plist` exists and contains valid credentials
- Check that URL schemes are properly configured in Info.plist
- Ensure bundle ID matches your Google OAuth configuration
- Verify the REVERSED_CLIENT_ID URL scheme is in Info.plist

### SSL Certificate Issues (Development)
The app is configured to accept localhost connections. For production, ensure you have valid SSL certificates.

### Authentication Issues
If you encounter authentication problems:
1. Ensure cookies are enabled
2. Check that the Rails API endpoints are accessible
3. Verify cookie synchronization between HTTPCookieStorage and WKWebsiteDataStore
4. Check AuthenticationManager for any session persistence issues

### Stream Chat Loading Issues
If Stream Chat doesn't load:
1. Verify Stream API keys are configured in Rails
2. Check that the token endpoint returns a valid JWT
3. Ensure StreamChatLauncherViewController properly handles token fetching

## Production Deployment

1. Update the `baseURL` in `TabBarController.swift` to your production URL
2. Ensure Info.plist has proper SSL configuration (remove localhost exception)
3. Configure proper app icons and launch screens
4. Test thoroughly on physical devices
5. Submit to App Store

## Support

For issues or questions, contact the development team or check the main project documentation.