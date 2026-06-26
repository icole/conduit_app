# iOS Staging Configuration Guide

## Goal
Have both staging and production versions of the app installed on the same device simultaneously.

## Steps

### 1. Create a Staging Scheme in Xcode

1. Open `ios/Conduit/Conduit.xcodeproj` in Xcode
2. Click on the scheme dropdown (top toolbar) → **Manage Schemes**
3. Select the existing scheme → **Duplicate**
4. Rename it to `Conduit Staging`
5. Click **Close**

### 2. Create Staging Build Configuration

1. In Xcode, select the project (Conduit) in the navigator
2. Select the project under PROJECT (not TARGETS)
3. Go to the **Info** tab
4. Under **Configurations**, duplicate `Debug` → rename to `Staging`
5. Optionally: Duplicate `Release` → rename to `Release Staging` (for production-like staging builds)

### 3. Edit Staging Scheme

1. Click scheme dropdown → **Edit Scheme** → Select `Conduit Staging`
2. For each action (Run, Test, Profile, Analyze, Archive):
   - Change **Build Configuration** to `Staging`
3. Click **Close**

### 4. Add Staging Bundle Identifier

1. Select the **Conduit** target (under TARGETS)
2. Go to **Build Settings** tab
3. Search for "Product Bundle Identifier"
4. Click the arrow to expand configurations
5. For `Staging` configuration, set: `com.colecoding.conduit.staging`
6. For `Debug` and `Release`, keep: `com.colecoding.conduit`

### 5. Add Staging Display Name

1. Still in **Build Settings**
2. Search for "Product Name"
3. For `Staging` configuration, set: `Conduit Staging`
4. For `Debug` and `Release`, keep: `Conduit`

### 6. Add Staging App Icon (Optional but Recommended)

**Option A: Use Asset Catalog Variants**

1. In Xcode, open `Assets.xcassets`
2. Right-click **AppIcon** → **Duplicate**
3. Rename to **AppIconStaging**
4. Add a badge or different color to staging icons (use an image editor)
5. In **Build Settings**, search for "App Icon"
6. For `Staging` configuration: Set asset catalog app icon set name to `AppIconStaging`

**Option B: Quick Badge Overlay**

You can add a "STAGING" banner overlay to your existing icons using free tools like:
- https://icon.kitchen (online)
- https://appicon.co (online)
- Badge app icons in Photoshop/Figma

### 7. Configure Staging Backend URL

Create a staging configuration file:

**File: `ios/Conduit/Conduit/Config/StagingConfig.xcconfig`**

```
// Staging Configuration
BACKEND_URL = https:/$()/conduit-staging.crowwoods.com
PRODUCT_BUNDLE_IDENTIFIER = com.colecoding.conduit.staging
PRODUCT_NAME = Conduit Staging
```

Then in Xcode:
1. Project → Info tab
2. Under **Configurations** → **Staging**
3. Set configuration file to `StagingConfig.xcconfig`

### 8. Update AppConfig to Use Environment

Edit `AppConfig.swift` to detect staging vs production:

```swift
import Foundation

struct AppConfig {
    static var baseURL: URL {
        #if STAGING
        return URL(string: "https://conduit-staging.crowwoods.com")!
        #else
        return URL(string: "https://conduit.crowwoods.com")!
        #endif
    }

    // ... rest of config
}
```

Add custom flag in Build Settings:
1. Search for "Swift Compiler - Custom Flags"
2. Under "Active Compilation Conditions"
3. For `Staging` configuration, add: `STAGING`

### 9. Register Staging Bundle ID

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Certificates, Identifiers & Profiles → Identifiers
3. Click **+** to create new App ID
4. Bundle ID: `com.colecoding.conduit.staging`
5. Name: `Conduit Staging`
6. Enable same capabilities as production (Push Notifications, Sign in with Apple, etc.)

### 10. Create Staging Provisioning Profile

1. In Apple Developer Portal → Profiles
2. Create new profile for `com.colecoding.conduit.staging`
3. Select your development/distribution certificate
4. Select test devices
5. Download and double-click to install

### 11. Configure Codemagic for Staging Builds

In `codemagic.yaml`, add staging workflow:

```yaml
workflows:
  ios-staging:
    name: iOS Staging Build
    instance_type: mac_mini_m2
    environment:
      groups:
        - app_store_credentials
      vars:
        XCODE_WORKSPACE: "ios/Conduit/Conduit.xcworkspace"
        XCODE_SCHEME: "Conduit Staging"
        BUNDLE_ID: "com.colecoding.conduit.staging"
        APP_STORE_CONNECT_ISSUER_ID: $APP_STORE_CONNECT_ISSUER_ID
        APP_STORE_CONNECT_KEY_IDENTIFIER: $APP_STORE_CONNECT_KEY_IDENTIFIER
        APP_STORE_CONNECT_PRIVATE_KEY: $APP_STORE_CONNECT_PRIVATE_KEY
    scripts:
      - name: Build iOS Staging
        script: |
          xcode-project build-ipa \
            --workspace "$XCODE_WORKSPACE" \
            --scheme "$XCODE_SCHEME" \
            --archive-flags="-destination 'generic/platform=iOS'"
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        api_key: $APP_STORE_CONNECT_PRIVATE_KEY
        key_id: $APP_STORE_CONNECT_KEY_IDENTIFIER
        issuer_id: $APP_STORE_CONNECT_ISSUER_ID
        submit_to_testflight: true
        beta_groups:
          - Internal Testers
```

## Testing

### Build Locally

```bash
# Build staging version
cd ios
xcodebuild -workspace Conduit.xcworkspace \
  -scheme "Conduit Staging" \
  -configuration Staging \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Or just select "Conduit Staging" scheme in Xcode and hit Run
```

### Install Both Apps

Once built:
- **Staging**: Shows as "Conduit Staging" with staging icon
- **Production**: Shows as "Conduit" with production icon

Both can coexist on the same device!

## Troubleshooting

**"Failed to register bundle identifier"**
- Ensure bundle ID is registered in Apple Developer Portal
- Ensure provisioning profile is installed
- Clean build folder: Product → Clean Build Folder

**App overwrites existing app**
- Check bundle identifier is different for staging configuration
- Verify you're building with the correct scheme

**"No provisioning profile found"**
- Download staging profile from Apple Developer Portal
- Or enable "Automatically manage signing" in Xcode target settings
