# Android Staging Configuration Guide

## Goal
Have both staging and production versions of the app installed on the same device simultaneously.

## Steps

### 1. Create Product Flavors in build.gradle

Edit `android/app/build.gradle`:

```gradle
android {
    namespace = "com.colecoding.conduit"
    compileSdk = 35

    // ... existing config ...

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

    // ... rest of config ...
}
```

### 2. Update App Name to Use Resource

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:name=".ConduitApplication"
    android:label="@string/app_name"
    <!-- ... rest of attributes ... -->
>
```

This will use the flavor-specific app name defined in build.gradle.

### 3. Create Staging Icon (Optional but Recommended)

**Option A: Separate Icon Per Flavor**

1. Create flavor-specific res directories:
   ```
   android/app/src/staging/res/mipmap-hdpi/ic_launcher.png
   android/app/src/staging/res/mipmap-mdpi/ic_launcher.png
   android/app/src/staging/res/mipmap-xhdpi/ic_launcher.png
   android/app/src/staging/res/mipmap-xxhdpi/ic_launcher.png
   android/app/src/staging/res/mipmap-xxxhdpi/ic_launcher.png
   ```

2. Add badge or different color to staging icons

**Option B: Quick Badge Tool**

Use Android Asset Studio to add a badge:
- https://romannurik.github.io/AndroidAssetStudio/icons-launcher.html
- Or use Image Asset tool in Android Studio: Right-click `res` → New → Image Asset

### 4. Update AppConfig to Use BuildConfig

Edit `android/app/src/main/java/com/colecoding/conduit/config/AppConfig.kt`:

```kotlin
package com.colecoding.conduit.config

import android.content.Context
import com.colecoding.conduit.BuildConfig

object AppConfig {
    fun getBaseUrl(context: Context): String {
        // Use BuildConfig which is set per flavor
        return BuildConfig.BASE_URL
    }

    // Alternative: Keep existing logic for local development
    fun getBaseUrlWithLocalOverride(context: Context): String {
        // Check for local config first (development)
        val localUrl = getLocalConfigUrl(context)
        if (localUrl != null) {
            return localUrl
        }

        // Fall back to flavor-specific URL
        return BuildConfig.BASE_URL
    }

    private fun getLocalConfigUrl(context: Context): String? {
        // Existing local config logic for development
        // ...
    }
}
```

### 5. Build Both Variants

Now you can build both variants:

```bash
cd android

# Build staging debug APK
./gradlew assembleStagingDebug

# Build production debug APK
./gradlew assembleProductionDebug

# Build staging release APK
./gradlew assembleStagingRelease

# Build production release APK
./gradlew assembleProductionRelease
```

Or in Android Studio:
1. **Build** → **Select Build Variant**
2. Choose: `stagingDebug` or `productionDebug`
3. Run the app

### 6. Configure Signing for Staging

Edit `android/app/build.gradle` to add staging signing config:

```gradle
android {
    signingConfigs {
        release {
            // Production signing
            storeFile file(System.getenv("CM_KEYSTORE_PATH") ?: "keystore.jks")
            storePassword System.getenv("CM_KEYSTORE_PASSWORD")
            keyAlias System.getenv("CM_KEY_ALIAS")
            keyPassword System.getenv("CM_KEY_PASSWORD")
        }

        staging {
            // Can use same keystore with different alias, or separate keystore
            storeFile file(System.getenv("CM_KEYSTORE_PATH") ?: "keystore.jks")
            storePassword System.getenv("CM_KEYSTORE_PASSWORD")
            keyAlias System.getenv("CM_KEY_ALIAS_STAGING") ?: System.getenv("CM_KEY_ALIAS")
            keyPassword System.getenv("CM_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            // ... other release config ...
        }

        debug {
            // Debug builds use debug signing
        }
    }

    // Apply signing to flavors
    productFlavors {
        production {
            // ... existing config ...
        }

        staging {
            // ... existing config ...
            // For release builds of staging
            signingConfig signingConfigs.staging
        }
    }
}
```

### 7. Update Google Services for Staging

If using Firebase/Google Services:

1. **Create separate Firebase project** for staging (recommended)
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Create new project: "Conduit Staging"
   - Add Android app with package: `com.colecoding.conduit.staging`
   - Download `google-services.json`

2. **Place in flavor directory**:
   ```
   android/app/src/staging/google-services.json
   android/app/src/production/google-services.json
   ```

### 8. Configure Codemagic for Staging Builds

In `codemagic.yaml`, add staging workflow:

```yaml
workflows:
  android-staging:
    name: Android Staging Build
    instance_type: linux_x2
    environment:
      groups:
        - google_play
      vars:
        PACKAGE_NAME: "com.colecoding.conduit.staging"
        GOOGLE_PLAY_TRACK: internal
    scripts:
      - name: Set up keystore
        script: |
          echo $CM_KEYSTORE | base64 --decode > $CM_KEYSTORE_PATH

      - name: Build Android Staging
        script: |
          cd android
          ./gradlew assembleStagingRelease

      - name: Sign APK
        script: |
          # APK is already signed via build.gradle signing config
          echo "APK signed during build"

    artifacts:
      - android/app/build/outputs/**/*.apk
      - android/app/build/outputs/**/*.aab

    publishing:
      google_play:
        credentials: $GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
        track: internal
        submit_as_draft: false
```

### 9. Register Staging App in Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. **Create app** → New app
3. Name: "Conduit Staging"
4. Package name: `com.colecoding.conduit.staging`
5. Set as **Internal testing** app (not public)

### 10. Test Both Apps Installed

After building:

```bash
# Install both APKs
adb install android/app/build/outputs/apk/staging/debug/app-staging-debug.apk
adb install android/app/build/outputs/apk/production/debug/app-production-debug.apk

# Verify both are installed
adb shell pm list packages | grep conduit
# Should show:
# package:com.colecoding.conduit
# package:com.colecoding.conduit.staging
```

On your device, you'll see:
- **Conduit** (production)
- **Conduit Staging** (staging)

Both can run simultaneously!

## Quick Build Commands

```bash
# Development (on device/emulator)
./gradlew installStagingDebug     # Install staging version
./gradlew installProductionDebug  # Install production version

# Release builds
./gradlew assembleStagingRelease
./gradlew assembleProductionRelease

# Build both at once
./gradlew assemble

# Clean before building
./gradlew clean assembleStagingDebug
```

## Android Studio Setup

1. Open `android/` folder in Android Studio
2. In **Build Variants** panel (left side):
   - Select `stagingDebug` for staging development
   - Select `productionDebug` for production development
3. Click Run ▶️

## Troubleshooting

**"Duplicate class found"**
- Clean build: `./gradlew clean`
- Invalidate caches: File → Invalidate Caches / Restart

**"App not installed - package conflicts"**
- Check applicationId is different for each flavor
- Uninstall existing app: `adb uninstall com.colecoding.conduit.staging`

**"BuildConfig.BASE_URL not found"**
- Ensure you're using Android Gradle Plugin 8.0+
- Or enable buildConfig explicitly:
  ```gradle
  android {
      buildFeatures {
          buildConfig = true
      }
  }
  ```

**Google Services error**
- Ensure `google-services.json` is in the correct flavor directory
- Or use `src/main/google-services.json` and update package name manually

## Summary

After setup, you'll have:
- **Production**: `com.colecoding.conduit` → "Conduit"
- **Staging**: `com.colecoding.conduit.staging` → "Conduit Staging"

Both with different icons, connected to different backends, installable side-by-side!
