# Dual App Setup - Quick Start

Run production AND staging apps on the same device simultaneously.

## Overview

After setup, you'll have:

| Version | iOS | Android |
|---------|-----|---------|
| **Production** | `com.colecoding.conduit`<br/>"Conduit" | `com.colecoding.conduit`<br/>"Conduit" |
| **Staging** | `com.colecoding.conduit.staging`<br/>"Conduit Staging" | `com.colecoding.conduit.staging`<br/>"Conduit Staging" |

## iOS Setup (30 mins)

See detailed guide: [iOS_STAGING_SETUP.md](iOS_STAGING_SETUP.md)

**Quick steps:**
1. Duplicate scheme → "Conduit Staging"
2. Create `Staging` build configuration
3. Set bundle ID: `com.colecoding.conduit.staging`
4. Set display name: `Conduit Staging`
5. Add `STAGING` compiler flag
6. Update AppConfig to use flag
7. Register bundle ID in Apple Developer Portal
8. Create provisioning profile

**Build:**
```bash
# In Xcode: Select "Conduit Staging" scheme → Run
```

## Android Setup (20 mins)

See detailed guide: [ANDROID_STAGING_SETUP.md](ANDROID_STAGING_SETUP.md)

**Quick steps:**
1. Edit `android/app/build.gradle`
2. Add product flavors (see below)
3. Update AppConfig to use BuildConfig
4. Build both variants

**Add to build.gradle:**
```gradle
android {
    flavorDimensions = ["environment"]

    productFlavors {
        production {
            dimension "environment"
            applicationId "com.colecoding.conduit"
            resValue "string", "app_name", "Conduit"
            buildConfigField "String", "BASE_URL", '"https://conduit.crowwoods.com"'
        }

        staging {
            dimension "environment"
            applicationId "com.colecoding.conduit.staging"
            resValue "string", "app_name", "Conduit Staging"
            buildConfigField "String", "BASE_URL", '"https://conduit-staging.crowwoods.com"'
            versionNameSuffix "-staging"
        }
    }
}
```

**Build:**
```bash
cd android
./gradlew installStagingDebug    # Install staging
./gradlew installProductionDebug # Install production
```

## Optional but Recommended: Different Icons

**Why:** Easily distinguish staging from production at a glance

**iOS:**
1. Duplicate AppIcon in Assets.xcassets → "AppIconStaging"
2. Add badge (use https://icon.kitchen)
3. Set in Build Settings for Staging configuration

**Android:**
1. Create `android/app/src/staging/res/mipmap-*/ic_launcher.png`
2. Add badge to icons (use Android Asset Studio)

## Verification

After setup, test that both apps are installed:

**iOS:**
```bash
# Check on connected device
xcrun simctl listapps booted | grep -i conduit

# Or just look at home screen - you should see:
# - "Conduit" (production)
# - "Conduit Staging" (staging)
```

**Android:**
```bash
adb shell pm list packages | grep conduit
# Should show:
# package:com.colecoding.conduit
# package:com.colecoding.conduit.staging
```

## Testing Your Notification Feature

Now you can test the notification navigation on staging WITHOUT affecting production:

1. **Install staging build** on your device
2. **Login** to staging environment
3. **Send a test message** from another user
4. **Background the app**
5. **Tap the notification**
6. **Verify** it navigates to the correct channel

All while keeping your production app installed and functional!

## Codemagic Integration

Update `codemagic.yaml` to build both variants:

**iOS:**
- `ios-production` → scheme "Conduit" → TestFlight production track
- `ios-staging` → scheme "Conduit Staging" → TestFlight internal track

**Android:**
- `android-production` → flavor "production" → Google Play production
- `android-staging` → flavor "staging" → Google Play internal track

## Common Issues

**iOS: "No provisioning profile"**
- Register `com.colecoding.conduit.staging` in Apple Developer Portal
- Create provisioning profile for staging bundle ID

**Android: "Duplicate class"**
- Run `./gradlew clean`
- Rebuild

**App overwrites existing installation**
- Check bundle ID / application ID is different
- For iOS: Verify you're using the correct scheme
- For Android: Verify you're using the correct flavor

## Next Steps

1. Follow detailed setup guides (links at top)
2. Build both variants locally
3. Test on your device
4. Configure Codemagic for automated staging builds
5. Add to your workflow: `STAGING_WORKFLOW.md`

## Resources

- iOS detailed guide: [iOS_STAGING_SETUP.md](iOS_STAGING_SETUP.md)
- Android detailed guide: [ANDROID_STAGING_SETUP.md](ANDROID_STAGING_SETUP.md)
- Staging workflow: [../STAGING_WORKFLOW.md](../STAGING_WORKFLOW.md)
- Icon badge tools:
  - https://icon.kitchen (iOS + Android)
  - https://romannurik.github.io/AndroidAssetStudio/ (Android)
  - https://appicon.co (iOS)
