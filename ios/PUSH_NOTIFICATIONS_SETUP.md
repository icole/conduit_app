# Push Notifications Setup for Stream Chat

## Overview
Push notifications have been integrated into the Conduit iOS app for Stream Chat messages. This guide explains how to complete the setup for production deployment.

## iOS Implementation (Already Completed)

The iOS app has been configured with:
- Push notification registration in AppDelegate
- Device token management and storage
- Stream Chat SDK integration for APNs
- Notification handling when app is in foreground/background
- Automatic navigation to chat tab when notification is tapped

## Required Setup Steps

### 1. Enable Push Notifications Capability in Xcode

1. Open the Conduit project in Xcode
2. Select the Conduit target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add "Push Notifications"

### 2. Create APNs Certificate or Key

You have two options for authenticating with APNs:

#### Option A: APNs Authentication Key (Recommended)
1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to Certificates, Identifiers & Profiles
3. Go to Keys
4. Click the "+" button to create a new key
5. Name it (e.g., "Conduit Push Notifications")
6. Enable "Apple Push Notifications service (APNs)"
7. Download the .p8 file (save it securely - you can only download it once!)
8. Note the Key ID

#### Option B: APNs Certificate
1. Open Keychain Access on your Mac
2. Request a Certificate from a Certificate Authority
3. Upload the CSR to Apple Developer Portal
4. Create a Push Notification certificate for your app
5. Download and install the certificate
6. Export it as a .p12 file

### 3. Configure Stream Dashboard

1. Log into [Stream Dashboard](https://dashboard.getstream.io)
2. Select your app
3. Go to Push Notifications settings
4. For iOS/APNs:

   **If using APNs Key:**
   - Upload the .p8 file
   - Enter the Key ID
   - Enter your Team ID
   - Enter your Bundle ID (com.hoamobileapp.Conduit)
   - Select environment (Development/Production)

   **If using APNs Certificate:**
   - Upload the .p12 file
   - Enter the certificate password
   - Enter your Bundle ID (com.hoamobileapp.Conduit)
   - Select environment (Development/Production)

### 4. Test Push Notifications

#### In Development:
1. Build and run the app on a physical device (simulators don't support push notifications)
2. Accept the push notification permission when prompted
3. Check Xcode console for "Device Token: ..." log
4. Send a test message from another device/user
5. Verify notification appears

#### In Production:
1. Archive and distribute the app via TestFlight or Ad Hoc
2. Ensure Stream Dashboard has Production APNs configured
3. Test with real devices

## Troubleshooting

### Common Issues:

**No Device Token Generated:**
- Ensure you're testing on a physical device, not simulator
- Check that Push Notifications capability is enabled
- Verify provisioning profile includes push notifications

**Notifications Not Received:**
- Check Stream Dashboard push configuration
- Verify correct environment (Development vs Production)
- Check device notification settings for your app
- Look for errors in Stream Dashboard push logs

**"No valid 'aps-environment' entitlement" Error:**
- Regenerate provisioning profiles after adding Push Notifications capability
- Clean build folder and rebuild

**Token Registration Fails:**
- Ensure Stream Chat client is connected before registering token
- Check Stream API key and configuration

## Implementation Details

### Device Token Flow:
1. App requests push permission on launch
2. If granted, iOS provides device token
3. Token is sent to Stream Chat if user is logged in
4. If not logged in, token is stored in UserDefaults
5. When user logs in and Stream connects, pending token is registered

### Notification Handling:
- **Foreground:** Notifications display as banners even when app is open
- **Background:** Standard iOS notification behavior
- **Tap Action:** Opens app and navigates to Chat tab

### Key Files Modified:
- `AppDelegate.swift` - Push notification registration and handling
- `SceneDelegate.swift` - Navigation to chat tab on notification tap
- `StreamChatViewController.swift` - Pending token registration

## Security Notes

- Never commit APNs keys or certificates to version control
- Store APNs credentials securely
- Use separate keys/certificates for Development and Production
- Rotate keys periodically for security

## Additional Resources

- [Stream Push Notifications Documentation](https://getstream.io/chat/docs/ios-swift/push-notifications/)
- [Apple Push Notification Documentation](https://developer.apple.com/documentation/usernotifications)
- [APNs Best Practices](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)