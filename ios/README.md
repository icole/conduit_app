# Conduit iOS App

This is the iOS Hotwire Native app for the Conduit HOA management system.

## Features

- **Tab Navigation**: Two tabs for Home (main app) and Chat (Element/Matrix)
- **Hotwire Native**: Full Rails app functionality in a native iOS shell
- **Element Web Integration**: Secure, private community chat via Matrix

## Requirements

- Xcode 14.0+
- iOS 15.0+
- Swift 5.7+

## Setup Instructions

### 1. Install Dependencies

```bash
cd ios/Conduit
swift package resolve
```

### 2. Open in Xcode

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

## Troubleshooting

### SSL Certificate Issues (Development)
The app is configured to accept localhost connections. For production, ensure you have valid SSL certificates.

### Authentication Issues
If you encounter authentication problems:
1. Ensure cookies are enabled
2. Check that the Rails session is properly configured
3. Verify the authentication flow works in Safari first

### Element Web Loading Issues
If Element doesn't load:
1. Verify Element Web files are in `public/element/`
2. Check that the iframe src in the Rails view is correct
3. Ensure proper CORS headers are configured

## Production Deployment

1. Update the `baseURL` in `TabBarController.swift` to your production URL
2. Ensure Info.plist has proper SSL configuration (remove localhost exception)
3. Configure proper app icons and launch screens
4. Test thoroughly on physical devices
5. Submit to App Store

## Support

For issues or questions, contact the development team or check the main project documentation.