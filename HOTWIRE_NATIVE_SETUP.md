# Hotwire Native Setup for HOA Chat

This is a minimal setup to wrap the chat page in a native iOS app using Hotwire Native.

## What's Included

1. **Rails Backend Updates:**
   - Added `TurboNative` concern to detect mobile app requests
   - Created minimal layout without navbar for native apps
   - Adjusted chat view to be fullscreen on mobile

2. **iOS App Starter:**
   - Basic iOS app that loads the chat page directly
   - Uses Hotwire Native to wrap the web view
   - Minimal configuration - just point and shoot!

## Quick Start (iOS)

### Prerequisites
- Xcode 15+ installed
- iOS Simulator or physical device
- Rails server running locally

### Step 1: Create a New iOS App in Xcode

1. Open Xcode
2. Create a new project: **File → New → Project**
3. Choose **iOS → App**
4. Configure:
   - Product Name: `HOAChat`
   - Organization Identifier: `com.yourorg`
   - Interface: **SwiftUI**
   - Language: **Swift**

### Step 2: Add Hotwire Native Package

1. In Xcode, select your project in the navigator
2. Select your app target
3. Go to **Package Dependencies** tab
4. Click the **+** button
5. Enter URL: `https://github.com/hotwired/hotwire-native-ios`
6. Click **Add Package**
7. Select **HotwireNative** and click **Add Package**

### Step 3: Replace ContentView.swift

Replace the default `ContentView.swift` with this minimal implementation:

```swift
import SwiftUI
import HotwireNative

struct ContentView: View {
    @State private var navigator = Navigator()

    var body: some View {
        NavigatorView(navigator: navigator)
            .onAppear {
                // For local testing
                let url = URL(string: "http://localhost:3000/chat")!

                // For production, change to:
                // let url = URL(string: "https://your-domain.com/chat")!

                navigator.route(to: url)
            }
    }
}
```

### Step 4: Update App Entry Point

Replace your `HOAChatApp.swift` (or `App.swift`) with:

```swift
import SwiftUI
import HotwireNative

@main
struct HOAChatApp: App {
    init() {
        // Configure Hotwire Native
        Hotwire.config.userAgent = "HOA Chat iOS (Turbo Native)"
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Step 5: Allow Local Network Access (for development)

Add to your `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Step 6: Run the App

1. Start your Rails server:
   ```bash
   bin/rails server
   ```

2. In Xcode, select an iOS Simulator or your device
3. Click **Run** (⌘R)
4. The app should launch and load the chat interface!

## Testing the Native Detection

When the app loads, the Rails backend will detect it's a Turbo Native app and:
- Hide the web navbar
- Use fullscreen layout
- Optimize for mobile display

You can verify this is working by checking the Rails logs:

```bash
tail -f log/development.log | grep "Turbo Native"
```

## Android Setup

For Android, you can use [Hotwire Native Android](https://github.com/hotwired/hotwire-native-android):

1. Create a new Android project
2. Add the Hotwire Native dependency
3. Create a simple Activity that loads the chat URL

Example `MainActivity.kt`:

```kotlin
class MainActivity : HotwireActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // For local testing
        startLocation = "http://10.0.2.2:3000/chat"

        // For production
        // startLocation = "https://your-domain.com/chat"
    }
}
```

## Production Deployment

For production:

1. Update the URL in your app to point to your production domain
2. Ensure HTTPS is configured (required for App Store)
3. Add proper authentication handling if needed
4. Test on real devices

## Tips

- **Authentication**: The current setup uses your existing Rails authentication
- **Push Notifications**: Can be added later using Stream Chat's push notification support
- **Offline Support**: Stream Chat SDK handles offline/online states automatically
- **Custom Navigation**: You can add native navigation bars if needed

## Troubleshooting

### App shows blank screen
- Check Rails server is running
- Verify the URL in the app matches your Rails server
- Check network permissions in Info.plist

### Chat doesn't load
- Ensure Stream Chat credentials are configured
- Check Rails logs for errors
- Verify user is logged in

### Layout issues
- The app detects "Turbo Native" in the user agent
- Verify the turbo_native_app? helper is working
- Check the turbo_native layout is being used

## Next Steps

This minimal setup gets you started quickly. You can enhance it with:

- Native navigation bars
- Push notifications
- Deep linking to specific channels
- Native user profiles
- Offline message queue
- Native image picker for file uploads

The beauty of Hotwire Native is you can start simple and progressively enhance with native features as needed!