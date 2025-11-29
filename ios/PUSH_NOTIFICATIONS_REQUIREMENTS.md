# Push Notifications Requirements

## ⚠️ Important: Paid Apple Developer Account Required

Push Notifications on iOS require a **paid Apple Developer Program membership** ($99/year).

### Current Status:
- Your app is using a **Personal Development Team** (free account)
- Personal teams do **NOT** support Push Notifications capability
- Bundle ID: `com.colecoding.Conduit` (will need updating to match your paid account)

### What You Need:

1. **Apple Developer Program Membership**
   - Cost: $99/year
   - Sign up at: https://developer.apple.com/programs/
   - Provides access to:
     - Push Notifications
     - App Store distribution
     - TestFlight beta testing
     - Advanced capabilities
     - APNs certificates/keys

2. **After Enrollment:**
   - Push Notifications will appear in Xcode capabilities
   - You'll be able to create APNs keys in Apple Developer portal
   - Can configure Stream Dashboard with APNs credentials

### Current Code Status:
The push notification code is implemented but temporarily disabled:
- Implementation is complete and ready
- Code is commented out in `AppDelegate.swift` line 18
- Simply uncomment `registerForPushNotifications()` after getting paid account

### To Enable Push Notifications:

1. **Get paid Apple Developer account**
2. **In Xcode:**
   - Change Team to your paid developer team
   - Add Push Notifications capability
   - Update provisioning profiles
3. **In AppDelegate.swift:**
   - Uncomment line 18: `registerForPushNotifications()`
   - Remove the warning message
4. **In Apple Developer Portal:**
   - Create APNs Key or Certificate
5. **In Stream Dashboard:**
   - Upload APNs credentials

### Alternative for Testing:
While you can't test real push notifications without a paid account, you can:
- Test all other Stream Chat features
- Verify in-app messaging works
- See console logs where push notifications would trigger
- Develop and test everything else in your app

### Bundle ID Consideration:
Your current Bundle ID is `com.colecoding.Conduit`. When you get a paid account, you might want to:
- Keep this Bundle ID if you'll use the same account
- OR change it to match your organization (e.g., `com.hoamobileapp.Conduit`)

The app will continue to work perfectly for all features except push notifications. Once you have a paid developer account, enabling push notifications will take just a few minutes since all the code is already in place!