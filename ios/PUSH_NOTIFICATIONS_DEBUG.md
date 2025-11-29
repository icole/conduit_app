# Push Notifications Debug Checklist

## 1. Check Console Logs

When the app launches, you should see:
```
📱 APNS Device Token Received:
  → Raw token: [base64 string]
  → Hex token: [hex string]
  → Token length: 32 bytes
📤 Sending token to ChatManager...
```

Then when Stream Chat connects:
```
📲 ChatManager.registerDeviceToken called
  → Token size: 32 bytes
  ✅ Client ready, user: [userId]
  📤 Registering with Stream using provider: 'Stream-Push-Notifications'
  ✅ Successfully registered device token with Stream Chat!
     Provider: Stream-Push-Notifications
     User: [userId]
```

## 2. Requirements Checklist

### On Your Device:
- [ ] **Physical device** (not simulator) - Push notifications don't work on simulator
- [ ] **iOS 10+** installed
- [ ] **Notification permissions granted** - Check Settings > Your App > Notifications
- [ ] **Not in Do Not Disturb mode**
- [ ] **App is either in background or closed** (or in foreground with our code)

### In Xcode Project:
- [ ] **Push Notifications capability added** (check Signing & Capabilities)
- [ ] **Valid provisioning profile** with push notifications entitlement
- [ ] **Correct Team selected** (paid developer account, not Personal Team)
- [ ] **Bundle ID matches** what's in Stream Dashboard

### In Stream Dashboard:
- [ ] **APNs credentials uploaded** (either .p8 key or .p12 certificate)
- [ ] **Correct environment selected**:
  - Development: For builds from Xcode
  - Production: For TestFlight/App Store
- [ ] **Bundle ID matches** exactly (case-sensitive)
- [ ] **Push provider name** is "Stream-Push-Notifications"

### Testing:
- [ ] **Send message from different user** - You won't get notifications for your own messages
- [ ] **User is member of the channel** - Must be in the channel to receive notifications
- [ ] **App in background/closed** when message sent (or check foreground logs)

## 3. Common Issues and Solutions

### "No device token generated"
- Make sure you're on a physical device
- Check Push Notifications capability is enabled
- Verify provisioning profile includes push entitlement

### "Token registered but no notifications"
1. **Check Stream Dashboard logs:**
   - Go to Stream Dashboard > Your App > Push Notifications > Logs
   - Look for any errors when notifications are sent

2. **Verify environment mismatch:**
   - Xcode builds use Development APNS
   - TestFlight/App Store use Production APNS
   - Make sure both are configured in Stream

3. **Test with Stream's test tool:**
   - Stream Dashboard > Push Notifications > Send Test Notification
   - Enter your device token
   - Send a test

### "Getting token registration error"
Check the console for the specific error:
- **"push provider not found"** - Provider name mismatch
- **"invalid token"** - Environment mismatch (dev vs prod)
- **"user not found"** - User not connected to Stream

## 4. How to Test

### Method 1: Using Two Devices
1. Install app on Device A (your device)
2. Install app on Device B (or use web)
3. Log in as User A on Device A
4. Log in as User B on Device B
5. Put Device A app in background
6. Send message from Device B
7. Device A should receive notification

### Method 2: Using Web + Device
1. Install app on your device
2. Log in on device
3. Put app in background
4. Open web app in different browser/incognito
5. Log in as different user
6. Send message from web
7. Device should receive notification

### Method 3: Test in Foreground
1. Keep app open on device
2. Send message from another user
3. Check console for:
   ```
   📬 Notification received while app in FOREGROUND:
     → Title: [message title]
     → Body: [message body]
   ```

## 5. Debugging Commands

### Check if token is stored:
```swift
// In LLDB debugger:
po UserDefaults.standard.data(forKey: "pendingDeviceToken")
```

### Check Stream client state:
```swift
po ChatManager.shared.chatClient?.currentUserId
po ChatManager.shared.chatClient?.connectionStatus
```

### Force re-register token:
```swift
// Add this temporarily to test:
if let token = UserDefaults.standard.data(forKey: "pendingDeviceToken") {
    ChatManager.shared.registerDeviceToken(token)
}
```

## 6. Stream Dashboard URLs

- **Dashboard:** https://dashboard.getstream.io
- **Push Settings:** Dashboard > Your App > Chat > Push Notifications
- **Push Logs:** Dashboard > Your App > Chat > Push Notifications > Logs
- **Test Tool:** Dashboard > Your App > Chat > Push Notifications > Send Test

## 7. Final Checks

If everything above is correct but still not working:

1. **Delete and reinstall app** - Clears any cached settings
2. **Check Apple Developer Portal** - Ensure certificates haven't expired
3. **Try creating new APNs key** - Sometimes keys get corrupted
4. **Check Stream status** - https://status.getstream.io/
5. **Enable verbose logging** in Stream SDK:
   ```swift
   LogConfig.level = .debug
   ```

## Need More Help?

- Stream Support: https://getstream.io/support/
- Stream Docs: https://getstream.io/chat/docs/ios-swift/push-notifications/
- Check device logs: Xcode > Window > Devices and Simulators > View Device Logs