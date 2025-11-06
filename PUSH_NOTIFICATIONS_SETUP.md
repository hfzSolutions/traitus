# Push Notifications Setup Guide

This guide explains how to set up and use OneSignal push notifications in Traitus.

## 📋 Overview

Traitus uses **OneSignal** for push notifications across iOS, Android, and Web platforms. Notifications are optional and can be easily enabled by adding your OneSignal App ID to the environment configuration.

## ✨ Features

- ✅ **Cross-platform**: Works on iOS, Android, and Web
- ✅ **Easy setup**: Just add your OneSignal App ID
- ✅ **User targeting**: Link notifications to specific users
- ✅ **Custom data**: Send additional data with notifications
- ✅ **Segmentation**: Tag users for targeted notifications
- ✅ **Graceful fallback**: App works fine without notifications

## 🚀 Quick Start

### 1. Create a OneSignal Account

1. Go to [https://onesignal.com](https://onesignal.com)
2. Sign up for a free account
3. Create a new app in the OneSignal dashboard

### 2. Get Your App ID

1. Open your OneSignal app dashboard
2. Go to **Settings** → **Keys & IDs**
3. Copy your **OneSignal App ID**

### 3. Add App ID to Environment

Edit your `.env` file and add:

```env
# OneSignal Push Notifications
ONESIGNAL_APP_ID=your_onesignal_app_id_here
```

That's it! The app will automatically initialize OneSignal on startup.

## 📱 Platform-Specific Setup

### iOS Setup

For iOS push notifications, you need to configure APNs (Apple Push Notification service):

#### Step 1: Enable Push Notifications in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** target
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes** and enable:
   - ✅ Remote notifications

#### Step 2: Configure OneSignal with APNs

1. In OneSignal dashboard, go to **Settings** → **Platforms**
2. Click **Apple iOS** → **Configure**
3. Follow the wizard to upload your APNs authentication key or certificate

You can use:
- **APNs Auth Key** (recommended, easier)
- **APNs Certificate** (traditional method)

**Get APNs Auth Key:**
1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles → Keys
3. Create a new key with **Apple Push Notifications service (APNs)** enabled
4. Download the `.p8` file (only available once!)
5. Upload to OneSignal with your Team ID and Key ID

### Android Setup

Android configuration is automatic! OneSignal handles FCM (Firebase Cloud Messaging) configuration automatically.

**Optional: Custom Firebase Project**

If you want to use your own Firebase project:

1. Create a Firebase project at [https://console.firebase.google.com](https://console.firebase.google.com)
2. Add your Android app to the project
3. Download `google-services.json`
4. In OneSignal dashboard, go to **Settings** → **Platforms** → **Google Android**
5. Upload your Firebase Server Key

For most use cases, OneSignal's automatic configuration is sufficient.

### Web Setup (Optional)

For web push notifications:

1. In OneSignal dashboard, go to **Settings** → **Platforms**
2. Click **Web Push** → **Configure**
3. Enter your site URL
4. Follow the integration instructions

## 🔧 Usage in Your App

### Basic Usage

The app automatically initializes OneSignal on startup. No additional code needed!

### Link Notifications to Users

To send notifications to specific users, call this after login:

```dart
// In your AuthProvider or after successful login
await NotificationService.setExternalUserId(userId);
```

Don't forget to clear it on logout:

```dart
// In your logout method
await NotificationService.clearExternalUserId();
```

### Check Notification Permission

```dart
final enabled = await NotificationService.areNotificationsEnabled();
if (!enabled) {
  // Show a prompt to enable notifications
  await NotificationService.requestPermission();
}
```

### User Segmentation (Optional)

Tag users for targeted notifications:

```dart
// Tag user as premium
await NotificationService.sendTag('user_type', 'premium');

// Tag user preferences
await NotificationService.sendTag('language', 'en');

// Remove a tag
await NotificationService.removeTag('user_type');
```

## 📤 Sending Notifications

### Method 1: OneSignal Dashboard (Easiest)

1. Go to OneSignal dashboard → **Messages** → **Push**
2. Click **New Push**
3. Compose your message
4. Select audience (all users, specific users, or segments)
5. Click **Send**

### Method 2: OneSignal REST API

Send notifications programmatically using the OneSignal API:

```dart
// Example: Send notification via HTTP request
final response = await http.post(
  Uri.parse('https://onesignal.com/api/v1/notifications'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Basic YOUR_REST_API_KEY',
  },
  body: jsonEncode({
    'app_id': 'YOUR_APP_ID',
    'include_external_user_ids': ['user_123'], // Your Supabase user ID
    'contents': {'en': 'You have a new message!'},
    'headings': {'en': 'New Message'},
    'data': {
      'chat_id': 'abc123',
      'type': 'new_message',
    },
  }),
);
```

### Method 3: Supabase Integration

Trigger notifications from Supabase using Database Triggers or Edge Functions.

**Option A: Supabase Edge Function**

Create a Supabase Edge Function to send OneSignal notifications:

```typescript
// supabase/functions/send-notification/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { userId, title, message, data } = await req.json()

  const response = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Basic ${Deno.env.get('ONESIGNAL_REST_API_KEY')}`,
    },
    body: JSON.stringify({
      app_id: Deno.env.get('ONESIGNAL_APP_ID'),
      include_external_user_ids: [userId],
      contents: { en: message },
      headings: { en: title },
      data: data || {},
    }),
  })

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
```

**Option B: Database Trigger + Webhook**

Create a database trigger that calls your Edge Function when new messages arrive:

```sql
-- Create function to notify on new message
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS trigger AS $$
BEGIN
  -- Call Edge Function to send notification
  PERFORM
    net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/send-notification',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb,
      body := json_build_object(
        'userId', (SELECT user_id FROM chats WHERE id = NEW.chat_id AND user_id != NEW.user_id),
        'title', 'New Message',
        'message', substring(NEW.content, 1, 100),
        'data', json_build_object('chat_id', NEW.chat_id)
      )::jsonb
    );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER on_message_created
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();
```

## 🎯 Notification Click Handling

Handle notification clicks to navigate to specific screens:

Edit `lib/services/notification_service.dart`:

```dart
OneSignal.Notifications.addClickListener((event) {
  final data = event.notification.additionalData;
  
  if (data != null) {
    final chatId = data['chat_id'];
    final type = data['type'];
    
    // Navigate to chat
    if (chatId != null && type == 'new_message') {
      // Use your navigation method
      // e.g., Navigator.push(...) or GetX/Provider navigation
    }
  }
});
```

## 🔒 Privacy & Permissions

### iOS

iOS shows a native permission dialog when you first request permission. Users can:
- Allow notifications
- Deny notifications
- Change settings later in iOS Settings

The app requests permission automatically on first launch. You can also request it manually:

```dart
await NotificationService.requestPermission();
```

### Android

Android 13+ requires notification permission. The SDK handles this automatically, but you can also request it manually:

```dart
await NotificationService.requestPermission();
```

## 🐛 Troubleshooting

### Notifications Not Working

**Check Environment Variable:**
```dart
// Verify in console
print('OneSignal App ID: ${dotenv.env['ONESIGNAL_APP_ID']}');
```

**Check Permission:**
```dart
final enabled = await NotificationService.areNotificationsEnabled();
print('Notifications enabled: $enabled');
```

**Check User ID:**
```dart
final userId = await NotificationService.getUserId();
print('OneSignal User ID: $userId');
```

### iOS Notifications Not Receiving

1. ✅ Verify APNs is configured in OneSignal dashboard
2. ✅ Check Push Notifications capability is enabled in Xcode
3. ✅ Test on a real device (simulator doesn't support push)
4. ✅ Ensure app is not in Do Not Disturb mode
5. ✅ Check iOS Settings → Notifications → Traitus

### Android Notifications Not Receiving

1. ✅ Verify FCM is configured (or using OneSignal's automatic config)
2. ✅ Check permission is granted (Android 13+)
3. ✅ Ensure Google Play Services is installed
4. ✅ Test on a real device
5. ✅ Check notification settings in Android

### Testing Notifications

1. **Use OneSignal Dashboard**:
   - Go to Messages → Push → New Push
   - Select "Test Users" or "All Users"
   - Send a test notification

2. **Check Device Logs**:
   ```bash
   # Flutter logs
   flutter logs
   
   # Look for "NotificationService:" messages
   ```

3. **Verify User ID**:
   ```dart
   // Get OneSignal User ID
   final id = await NotificationService.getUserId();
   print('User ID: $id');
   ```

## 📊 Analytics & Monitoring

OneSignal provides built-in analytics:

1. Go to OneSignal dashboard → **Analytics**
2. View:
   - Delivery rates
   - Open rates
   - Click-through rates
   - User engagement

## 💰 Pricing

OneSignal offers a generous free tier:

- ✅ **Free**: Unlimited devices, 10,000 notifications/month
- 💵 **Growth**: Starting at $9/month for more notifications
- 💼 **Professional**: Custom pricing for enterprise

For most indie apps and startups, the free tier is sufficient.

## 🔗 Useful Links

- [OneSignal Documentation](https://documentation.onesignal.com/)
- [Flutter SDK Reference](https://documentation.onesignal.com/docs/flutter-sdk)
- [OneSignal Dashboard](https://app.onesignal.com)
- [API Reference](https://documentation.onesignal.com/reference/create-notification)

## 🎓 Best Practices

1. **Don't Over-Notify**: Send relevant, valuable notifications only
2. **Personalize**: Use user data to send targeted messages
3. **Timing**: Send notifications at appropriate times
4. **Test**: Always test on real devices before production
5. **Track**: Monitor analytics to optimize engagement
6. **Respect Privacy**: Make notifications optional and easy to disable

## 🤝 Support

If you encounter issues:

1. Check OneSignal [documentation](https://documentation.onesignal.com/)
2. Visit OneSignal [support](https://onesignal.com/support)
3. Check Flutter plugin [issues](https://github.com/OneSignal/OneSignal-Flutter-SDK/issues)

---

**Next Steps:**
1. ✅ Create OneSignal account
2. ✅ Add App ID to `.env`
3. ✅ Configure iOS APNs (if targeting iOS)
4. ✅ Test notifications on real devices
5. ✅ Implement notification handling for your use cases

