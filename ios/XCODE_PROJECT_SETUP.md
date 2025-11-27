# Xcode Project Setup Instructions

## Creating the Xcode Project

Follow these steps to create the Xcode project with the correct structure:

### Step 1: Open Xcode and Create New Project

1. Open Xcode
2. Choose **File → New → Project** (or press ⌘⇧N)
3. Select **iOS** platform
4. Choose **App** template
5. Click **Next**

### Step 2: Configure Project Settings

Fill in the following information:

- **Product Name**: Conduit
- **Team**: Select your development team (or None for now)
- **Organization Identifier**: com.yourorganization (replace with your actual identifier)
- **Bundle Identifier**: Will auto-fill as com.yourorganization.Conduit
- **Interface**: **UIKit** (NOT SwiftUI)
- **Language**: Swift
- **Use Core Data**: ❌ Unchecked
- **Include Tests**: ✅ Checked (optional but recommended)

Click **Next**

### Step 3: Save Project Location

**IMPORTANT**: When prompted for location:
1. Navigate to: `/Users/icole/Workspace/conduit_app/ios/`
2. **DO NOT** create an additional folder
3. The project should be saved directly in the `ios` folder
4. Click **Create**

### Step 4: Delete Default Files

After project creation, delete these default files from Xcode:
- `ViewController.swift`
- `Main.storyboard`
- `Assets.xcassets` (we'll add back later if needed)
- `Base.lproj/LaunchScreen.storyboard` (we'll add back later if needed)

To delete: Select each file → Right-click → Delete → Move to Trash

### Step 5: Add Existing Source Files

1. In Xcode, right-click on the **Conduit** folder in the navigator
2. Choose **Add Files to "Conduit"...**
3. Navigate to `/Users/icole/Workspace/conduit_app/ios/Conduit/`
4. Select all three folders:
   - `App`
   - `Controllers`
   - `Resources`
5. Make sure these options are checked:
   - ✅ Copy items if needed (should be unchecked since files are already in place)
   - ✅ Create groups
   - ✅ Add to target: Conduit
6. Click **Add**

### Step 6: Update Project Settings

1. Click on the project name in the navigator
2. Select the **Conduit** target
3. Go to the **General** tab
4. Under **Deployment Info**:
   - Set **iOS Deployment Target** to 15.0 or higher
   - Uncheck **Supports multiple windows** (unless you want iPad multitasking)

5. Go to the **Info** tab
6. Find and delete the following entries (if they exist):
   - **Main storyboard file base name**
   - **Launch screen interface file base name** (we'll handle this programmatically)

### Step 7: Update Info.plist Location

1. Select the project in navigator
2. Select the **Conduit** target
3. Go to **Build Settings** tab
4. Search for "Info.plist"
5. Update **Info.plist File** path to: `Conduit/Resources/Info.plist`

### Step 8: Add Swift Package Dependencies

1. Select the project in navigator
2. Select the project name (not the target)
3. Go to **Package Dependencies** tab
4. Click the **+** button
5. Enter: `https://github.com/hotwired/hotwire-native-ios`
6. Rules: **Up to Next Major Version** → 1.0.0
7. Click **Add Package**
8. When prompted, add to the **Conduit** target
9. Click **Add Package**

### Step 9: Clean and Build

1. Press ⌘⇧K to clean the build folder
2. Press ⌘B to build the project
3. Fix any build errors (there shouldn't be any if steps were followed correctly)

### Step 10: Configure Scheme for Development

1. Click on the scheme selector (next to the run/stop buttons)
2. Choose **Edit Scheme...**
3. Under **Run** → **Arguments** → **Environment Variables**
4. Add: `DEBUG` = `1` (for development mode)

## Final Project Structure

Your Xcode project navigator should look like this:

```
Conduit
├── App
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Controllers
│   ├── TabBarController.swift
│   ├── Navigator.swift
│   ├── HotwireNativeViewController.swift
│   └── ChatViewController.swift
├── Resources
│   └── Info.plist
└── Products
    └── Conduit.app
```

## Running the App

1. Make sure your Rails server is running:
   ```bash
   cd /Users/icole/Workspace/conduit_app
   bin/rails server
   ```

2. Select a simulator or device
3. Press ⌘R to run

## Troubleshooting

### If you see "Could not find module 'HotwireNative'"
- Make sure the package dependency was added correctly
- Try: File → Packages → Resolve Package Versions

### If the app crashes on launch
- Check that Info.plist is properly configured
- Verify Main.storyboard reference was removed from project settings
- Check console for specific error messages

### If web content doesn't load
- Verify Rails server is running
- Check the URLs in TabBarController.swift
- For physical devices, use your Mac's IP address instead of localhost