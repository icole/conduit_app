# How to Add Push Notifications Capability in Xcode

## Step-by-Step Instructions:

### 1. Open Project Settings
- In Xcode, look at the left sidebar (Navigator)
- Click on the **top-level "Conduit" project** (has blue icon)
- This opens the project settings in the main editor

### 2. Select the Correct Target
- In the main editor, you'll see two sections in the left column:
  - PROJECT: Conduit
  - TARGETS: Conduit (and possibly others)
- Click on **"Conduit" under TARGETS** (not PROJECT)

### 3. Navigate to Signing & Capabilities
- At the top of the main editor, you'll see tabs:
  - General
  - **Signing & Capabilities** ← Click this one
  - Resource Tags
  - Info
  - Build Settings
  - Build Phases
  - Build Rules

### 4. Add Push Notifications Capability
- In the Signing & Capabilities tab, look for the **"+ Capability"** button
- It's located either:
  - Top-left of the editor area (below the tabs)
  - OR under your Team signing section
- Click **"+ Capability"**

### 5. Find and Add Push Notifications
- A window will pop up showing all available capabilities
- You can either:
  - Scroll to find "Push Notifications"
  - OR type "push" in the search box at the top
- Double-click **"Push Notifications"** to add it

### 6. Verify It Was Added
- After adding, you should see a new section called "Push Notifications" in your capabilities
- It will show with a checkmark if properly configured
- You might see "Steps: 2/2" or similar status

## Alternative Method (If + Capability is Hidden):

Sometimes the "+ Capability" button might be hidden. Try:

1. **Check your Team is selected:**
   - In Signing & Capabilities tab
   - Under "Signing" section
   - Make sure "Team" dropdown has your team selected
   - Check "Automatically manage signing" is checked

2. **If still not visible:**
   - Look for a small "+" icon in the top-left corner of the capabilities area
   - OR right-click in the capabilities area
   - OR check if there's an "All" and "Debug/Release" tab - make sure "All" is selected

## What It Should Look Like After Adding:

You should see a new section that says:

```
Push Notifications
✓ 2 Steps

- Add the Push Notifications feature to your App ID
- Add the Push Notifications entitlement to your entitlements file
```

## Common Issues:

**"+ Capability" button is grayed out:**
- Make sure you have a valid Team selected in the Signing section
- Ensure you're logged into Xcode with your Apple Developer account

**Can't find the button at all:**
- Make sure you've selected the TARGET (not PROJECT) in the left column
- Ensure you're on the "Signing & Capabilities" tab (not Build Settings)

**"Provisioning profile doesn't support push notifications":**
- After adding the capability, you may need to:
  - Click "Try Again" or the refresh button next to provisioning profile
  - Or wait a moment for Xcode to regenerate the profile

## Visual Guide:

```
Xcode Window Layout:
┌─────────────────────────────────────────────────┐
│  Navigator │         Main Editor                 │
│            │  ┌──────────────────────────────┐  │
│ ▼ Conduit  │  │ General | Signing & Capabilities │
│   (blue)   │  │         | ← Click here        │  │
│            │  ├──────────────────────────────┤  │
│ ▼ TARGETS  │  │  [+ Capability] ← Click this  │  │
│   Conduit  │  │                               │  │
│   ↑        │  │  Signing                      │  │
│   Click    │  │  ✓ Automatically manage...    │  │
│   this     │  │  Team: [Your Team]            │  │
│            │  │                               │  │
│            │  │  Push Notifications (after)   │  │
│            │  │  ✓ Configured                 │  │
└─────────────────────────────────────────────────┘
```

## Still Can't Find It?

If you still can't locate the option:
1. Make sure you're using a recent version of Xcode (14.0 or later)
2. Try: Editor menu → Add Capability → Push Notifications
3. Check that your Apple Developer account has access to push notifications
4. Try cleaning the build folder: Product → Clean Build Folder (⇧⌘K)

Once added, Xcode will automatically:
- Update your App ID on Apple Developer portal
- Add the push notifications entitlement to your project
- Update your provisioning profile