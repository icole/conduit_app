# iOS App Deployment Guide

This guide covers deploying the Conduit iOS app to physical devices and production.

## Prerequisites

- Apple Developer Account ($99/year)
- Xcode 14.0 or later
- Physical iOS device (iOS 15.0+)
- Production server URL

## Step 1: Configure Production URL

### Option A: Using Config.plist (Recommended)

1. Copy the template:
```bash
cp Conduit/Conduit/Config.plist.template Conduit/Conduit/Config.plist
```

2. Edit `Config.plist` and add your production URL:
```xml
<key>ProductionURL</key>
<string>https://your-actual-domain.com</string>
```

### Option B: Build-time Configuration

In Xcode:
1. Select your project in the navigator
2. Select your target
3. Go to Build Settings
4. Search for "Swift Compiler - Custom Flags"
5. Under "Other Swift Flags" for Release configuration, add:
   ```
   -D PRODUCTION_URL="https://your-actual-domain.com"
   ```

## Step 2: Configure Google Sign-In

1. Copy the template if not already done:
```bash
cp Conduit/Conduit/GoogleService-Info.plist.template Conduit/Conduit/GoogleService-Info.plist
```

2. Add your Google OAuth credentials to `GoogleService-Info.plist`

## Step 3: Configure Signing & Capabilities

1. Open `Conduit.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the "Conduit" target
4. Go to "Signing & Capabilities" tab
5. Enable "Automatically manage signing"
6. Select your Team (requires Apple Developer account)
7. Bundle Identifier should be unique (e.g., `com.yourcompany.conduit`)

## Step 4: Add Required Capabilities

In the "Signing & Capabilities" tab, ensure these are added:
- Associated Domains (for universal links if needed)
- Background Modes (if using background refresh)
- Push Notifications (if implementing push)

## Step 5: Deploy to Physical Device

### For Development Testing:

1. Connect your iPhone/iPad via USB
2. Trust the computer on your device when prompted
3. In Xcode, select your device from the device selector (top bar)
4. Click the Run button (▶️) or press `Cmd+R`
5. First time only: On your device, go to Settings → General → VPN & Device Management → Developer App → Trust

### For TestFlight Distribution:

1. **Archive the App:**
   - Select "Any iOS Device" as the destination
   - Product → Archive
   - Wait for the archive to complete

2. **Upload to App Store Connect:**
   - In the Organizer window, select your archive
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Choose "Upload"
   - Follow the prompts

3. **Configure in App Store Connect:**
   - Log in to [App Store Connect](https://appstoreconnect.apple.com)
   - Select your app
   - Go to TestFlight tab
   - Add internal or external testers
   - Submit for review (external testers only)

4. **Install via TestFlight:**
   - Testers receive an email invitation
   - Download TestFlight app from App Store
   - Enter invitation code or click link
   - Install and test the app

## Step 6: Production Checklist

Before deploying to production:

- [ ] Production URL is configured correctly
- [ ] Google Sign-In credentials are production-ready
- [ ] API key restrictions are set in Google Cloud Console
- [ ] App icons and launch screens are added
- [ ] Build configuration is set to Release
- [ ] Version and build numbers are updated
- [ ] SSL certificate pinning is configured (if required)
- [ ] Analytics/crash reporting is configured
- [ ] Privacy policy URL is updated in Info.plist
- [ ] App Store screenshots and metadata are prepared

## Building for Different Environments

### Debug Build (Development):
```bash
xcodebuild -project Conduit.xcodeproj -scheme Conduit -configuration Debug
```

### Release Build (Production):
```bash
xcodebuild -project Conduit.xcodeproj -scheme Conduit -configuration Release
```

### Ad-hoc Distribution:
1. Create an Ad-hoc provisioning profile in Apple Developer portal
2. Archive with Ad-hoc configuration
3. Export IPA for distribution

## Troubleshooting

### "Untrusted Developer" Error:
- Go to Settings → General → VPN & Device Management
- Select your developer account
- Tap "Trust"

### Provisioning Profile Issues:
- Xcode → Preferences → Accounts
- Select your account → Download Manual Profiles
- Or let Xcode manage automatically

### App Won't Connect to Server:
- Verify production URL in Config.plist
- Check server allows connections from iOS app
- Ensure SSL certificates are valid
- Check Info.plist for App Transport Security settings

### Google Sign-In Not Working:
- Verify bundle ID matches Google OAuth configuration
- Check URL schemes in Info.plist
- Ensure GoogleService-Info.plist has correct credentials

## Security Considerations

1. **Never commit sensitive data:**
   - Config.plist (contains production URLs)
   - GoogleService-Info.plist (contains API keys)
   - Any .p12 or .mobileprovision files

2. **API Key Protection:**
   - Restrict API keys in Google Cloud Console
   - Use bundle ID restrictions
   - Set up usage quotas

3. **Code Signing:**
   - Use proper provisioning profiles
   - Enable App Store encryption
   - Consider certificate pinning for sensitive APIs

## Monitoring & Analytics

Consider adding:
- Crashlytics or similar crash reporting
- Analytics (Firebase, Mixpanel, etc.)
- Performance monitoring
- User session recording (with consent)

## App Store Submission

When ready for App Store:

1. Ensure app meets [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
2. Prepare marketing materials:
   - App icon (1024x1024)
   - Screenshots for all device sizes
   - App preview videos (optional)
   - Description and keywords
3. Set up App Store Connect:
   - Create app record
   - Fill in all metadata
   - Set pricing and availability
   - Submit for review

## Useful Commands

### View connected devices:
```bash
xcrun xctrace list devices
```

### Install app via command line:
```bash
xcrun devicectl device install app --device [device-id] /path/to/app.app
```

### Export IPA from archive:
```bash
xcodebuild -exportArchive -archivePath path/to/archive.xcarchive -exportPath path/to/export -exportOptionsPlist path/to/options.plist
```

## Support

For deployment issues:
- Check Xcode build logs
- Review device console logs (Xcode → Window → Devices and Simulators)
- Verify all certificates and profiles are valid
- Ensure server endpoints are accessible from device network