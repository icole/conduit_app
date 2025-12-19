# Android Development Setup

## Debug Build Configuration

The debug build is configured to connect to your local Rails development server.

### Using Android Emulator
- URL: `http://10.0.2.2:3000` (automatically configured)
- This special IP address routes to your host machine's localhost

### Using Physical Device
For testing on a physical Android device:

1. **Find your computer's IP address:**
   ```bash
   # On macOS:
   ifconfig | grep "inet " | grep -v 127.0.0.1

   # Look for your local network IP (usually 192.168.x.x or 10.x.x.x)
   ```

2. **Create a config file** (optional override method):
   Create `android/app/src/main/assets/config.properties`:
   ```properties
   base_url=http://YOUR_COMPUTER_IP:3000
   ```
   Replace YOUR_COMPUTER_IP with your actual IP (e.g., 192.168.1.100)

3. **Start Rails server to accept external connections:**
   ```bash
   # Instead of just 'bin/rails server', use:
   bin/rails server -b 0.0.0.0
   ```

4. **Ensure your device is on the same network** as your development machine

### Switching Between Environments

- **Debug Build** → Local development server (localhost)
- **Release Build** → Production server (conduit.crowwoods.com)

### Building and Installing

```bash
# Clean build
cd android
./gradlew clean

# Build debug APK
./gradlew assembleDebug

# Install on connected device/emulator
./gradlew installDebug

# Or install specific APK
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Troubleshooting

1. **"Network error" or "Failed to connect"**
   - Ensure Rails server is running with `-b 0.0.0.0`
   - Check firewall settings
   - Verify device is on same network

2. **"You need to be logged in"**
   - Clear app data and re-authenticate
   - Check that your local Rails server has the correct RAILS_MASTER_KEY

3. **Physical device can't connect**
   - Use your computer's actual IP, not localhost or 127.0.0.1
   - Ensure Rails is bound to 0.0.0.0, not just localhost