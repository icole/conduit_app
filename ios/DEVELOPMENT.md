# iOS Development Setup

## Tab Structure

The iOS app now has 4 tabs matching the Android app:
1. **Home** - Dashboard/main feed
2. **Tasks** - Task management page
3. **Meals** - Meal scheduling page
4. **Chat** - Stream Chat messaging

## Build Configuration

### Debug Builds
- Automatically connects to `http://localhost:3000`
- No configuration needed for simulator
- Physical devices need special setup (see below)

### Release Builds
- Uses production URL from Config.plist
- Or compile-time PRODUCTION_URL flag
- Fallback URL configured in AppConfig.swift

## Running on iOS Simulator

1. **Start Rails server:**
   ```bash
   bin/rails server
   ```

2. **Open Xcode:**
   ```bash
   cd ios/Conduit
   open Conduit.xcodeproj
   ```

3. **Select scheme and simulator:**
   - Choose "Conduit" scheme
   - Select an iOS Simulator device
   - Click Run (⌘R)

The app will automatically connect to `localhost:3000`.

## Running on Physical Device

For physical iOS devices to connect to your local Rails server:

### Option 1: Using Mac's Network Name
1. Find your Mac's network name:
   - System Settings → Sharing → Local hostname
   - Usually something like: `YourName-MacBook.local`

2. Update AppConfig.swift for development:
   ```swift
   case .development:
       // For physical device testing
       url = URL(string: "http://YourName-MacBook.local:3000")!
   ```

3. Start Rails to accept external connections:
   ```bash
   bin/rails server -b 0.0.0.0
   ```

### Option 2: Using IP Address
1. Find your Mac's IP:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

2. Update AppConfig.swift with your IP:
   ```swift
   case .development:
       url = URL(string: "http://192.168.x.x:3000")!
   ```

3. Start Rails:
   ```bash
   bin/rails server -b 0.0.0.0
   ```

### Option 3: Using ngrok (Recommended for Teams)
1. Install and start ngrok:
   ```bash
   ngrok http 3000
   ```

2. Update AppConfig.swift with ngrok URL:
   ```swift
   case .development:
       url = URL(string: "https://xxxxx.ngrok.app")!
   ```

## Network Security

The Info.plist is configured to allow:
- HTTP connections to localhost (simulator)
- Local networking for development

For physical devices, you may need to add your specific domain to the exception list.

## Authentication

The app uses cookie-based authentication:
- Cookies are shared across all WebView tabs
- Session persists across app launches
- Google Sign-In is configured (requires GoogleService-Info.plist)

## Troubleshooting

### "Could not connect to server"
- Ensure Rails is running: `bin/rails server`
- For physical devices, ensure Rails is bound to 0.0.0.0
- Check that device is on same WiFi network

### WebView not loading
- Check Rails logs for errors
- Verify authentication cookies are set
- Try clearing WebView data in Settings

### Tab content blank
- Rails server may need to be restarted
- Check that routes exist: `/tasks`, `/meals`
- Verify user has access to these pages

## Building for Production

1. Create Config.plist with production URL:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>ProductionURL</key>
       <string>https://conduit.crowwoods.com</string>
   </dict>
   </plist>
   ```

2. Switch to Release configuration in Xcode
3. Archive and distribute

## Notes

- The iOS app uses Hotwire Native for WebView management
- Stream Chat SDK is integrated natively (not through WebView)
- All tabs share the same WKWebView configuration for session persistence
- Navigation is handled through the Navigator class which extends UINavigationController