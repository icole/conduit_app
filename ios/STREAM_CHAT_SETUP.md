# Stream Chat iOS Native Integration

## Overview

We've integrated Stream Chat's native iOS SDK for a superior chat experience in the Hotwire Native app. This provides:
- Native UI components
- Real-time messaging
- Offline support
- Push notifications (can be added)
- Native performance

## Architecture

```
Rails Backend:
  - Manages authentication
  - Generates Stream tokens
  - Syncs users to Stream

iOS App:
  - Native Stream Chat UI
  - Direct connection to Stream
  - Real-time updates
```

## Setup Instructions

### 1. Configure Stream Chat Credentials

Add to your `.env` file:
```
STREAM_API_KEY=your_stream_api_key_here
STREAM_API_SECRET=your_stream_api_secret_here
```

Get these from:
1. Go to https://getstream.io/
2. Sign up/login
3. Create a new app
4. Copy the API Key and Secret

### 2. Install Rails Dependencies

```bash
bundle install
```

### 3. Update iOS App in Xcode

1. Open the project in Xcode
2. Go to **File → Packages → Resolve Package Versions**
3. Wait for Stream Chat SDK to download
4. The package should include:
   - StreamChat
   - StreamChatUI

### 4. Build and Run

1. Clean Build Folder: **⌘⇧K**
2. Build: **⌘B**
3. Run: **⌘R**

## How It Works

### Rails Side

1. **Token Generation** (`/chat/token`):
   - Authenticates user via Rails session
   - Syncs user to Stream
   - Returns Stream token + API key

2. **User Sync**:
   - Creates/updates user in Stream
   - Sets role (admin/user)
   - Includes name and avatar

### iOS Side

1. **Chat Tab Tap**:
   - Loads `/chat` URL
   - Rails detects iOS app via user agent
   - Shows loading page

2. **Native Chat Launch**:
   - ChatViewController detects the prompt page
   - Launches StreamChatViewController
   - Fetches token from Rails

3. **Stream Connection**:
   - Authenticates with Stream
   - Loads channel list
   - Shows native chat UI

## Features Available

With Stream Chat native SDK:

- ✅ Real-time messaging
- ✅ Channel list
- ✅ Message threads
- ✅ Reactions
- ✅ Typing indicators
- ✅ Read receipts
- ✅ File/image sharing
- ✅ Message search
- ✅ Offline support
- ✅ Push notifications (with setup)

## Customization

### Channels

Edit the channel query in `StreamChatViewController.swift`:

```swift
let query = ChannelListQuery(
    filter: .and([
        .equal(.type, to: .team),  // Channel type
        .containMembers(userIds: [userId])  // User's channels
    ])
)
```

### Appearance

Customize Stream UI components:

```swift
// In StreamChatViewController.swift
Components.default.messageListVC.messageContentView.backgroundColor = .systemBlue
Components.default.channelListItemView.backgroundColor = .systemGray6
```

### Default Channels

To create default HOA channels, add a service:

```ruby
# app/services/stream_channel_service.rb
class StreamChannelService
  def self.setup_default_channels
    client = StreamChatClient.client

    # Create HOA channels
    channels = [
      { id: 'general', name: 'General Chat' },
      { id: 'announcements', name: 'Announcements' },
      { id: 'maintenance', name: 'Maintenance' }
    ]

    channels.each do |channel_data|
      channel = client.channel('team', channel_id: channel_data[:id])
      channel.create(current_user.id, name: channel_data[:name])
    end
  end
end
```

## Testing

### Test in iOS Simulator

1. Launch app
2. Login with test account
3. Tap Chat tab
4. Should see native Stream Chat UI

### Debug Tips

In Xcode console, you should see:
```
ChatViewController: Page loaded
Launching native Stream Chat
Stream token fetched successfully
Connected to Stream Chat
```

### Common Issues

**"Chat not configured" error**:
- Add Stream credentials to `.env`
- Restart Rails server

**Blank chat screen**:
- Check Xcode console for errors
- Verify token endpoint works
- Check network connection

**Authentication fails**:
- Ensure cookies are passed correctly
- Check Rails session is valid
- Verify user is logged in

## Production Deployment

### Rails

1. Set Stream credentials in production environment
2. Ensure HTTPS is configured
3. Set CORS if needed

### iOS

1. Update base URL in `StreamChatViewController.swift`
2. Configure push notifications (optional)
3. Set up proper SSL certificate handling
4. Test on physical device

## Push Notifications (Optional)

To add push notifications:

1. Enable Push Notifications capability in Xcode
2. Configure APNS in Stream Dashboard
3. Add push registration code:

```swift
// In AppDelegate.swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    chatClient?.currentUserController().addDevice(.apn(token: deviceToken))
}
```

## Advantages Over Web-Based Chat

| Feature | Native Stream SDK | Web-Based (Matrix/Element) |
|---------|------------------|---------------------------|
| Performance | ⚡ Native | 🐌 WebView overhead |
| Offline Support | ✅ Built-in | ❌ Limited |
| Push Notifications | ✅ Native | ❌ Not possible |
| UI/UX | ✅ Native iOS | ⚠️ Web limitations |
| Maintenance | ✅ Stream handles it | ⚠️ Self-managed |

## Conclusion

The native Stream Chat integration provides a superior chat experience for your HOA residents with minimal setup and maintenance. Stream handles all the infrastructure while you focus on your app.