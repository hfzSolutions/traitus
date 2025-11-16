# User Re-engagement System Documentation

## Overview

The User Re-engagement System automatically tracks user activity and sends personalized push notifications to inactive users via OneSignal. The system intelligently handles users with multiple AI chats by referencing their most recent/active chat in the notification.

**Key Features:**
- ✅ Tracks user activity automatically (app opens, message sends)
- ✅ Identifies inactive users (7+ days of inactivity)
- ✅ Sends personalized notifications with specific AI chat names
- ✅ Deep linking to specific chats when notification is tapped
- ✅ Respects user preferences (opt-out available)
- ✅ Frequency limits to prevent spam (max once per 7 days)
- ✅ Fully automated via scheduled cron job

## Architecture

### Components

1. **Activity Tracking** (Flutter App)
   - Tracks `last_app_activity` timestamp
   - Updates on app open, message send, and key interactions

2. **Database Schema** (Supabase)
   - `user_profiles.last_app_activity` - Last time user used the app
   - `user_profiles.re_engagement_enabled` - User opt-out preference
   - `user_profiles.last_re_engagement_sent` - Last notification timestamp

3. **Edge Function** (Supabase)
   - Identifies inactive users
   - Finds most relevant chat for each user
   - Sends notifications via OneSignal API

4. **Cron Job** (Supabase)
   - Runs daily at 10:00 AM UTC
   - Triggers Edge Function automatically

5. **Notification Handling** (Flutter App)
   - Deep linking to specific chats
   - Handles notification clicks

## Implementation Details

### Files Created

#### Database Migrations
- `supabase_migration_add_user_activity_tracking.sql`
  - Adds `last_app_activity`, `re_engagement_enabled`, `last_re_engagement_sent` columns
  - Creates indexes for efficient queries

- `supabase_migration_add_reengagement_cron.sql`
  - Instructions for setting up the cron job
  - SQL template for scheduling

#### Edge Function
- `supabase/functions/send-reengagement-notifications/index.ts`
  - Identifies inactive users (7+ days)
  - Finds most recent/active chat
  - Sends personalized OneSignal notifications
  - Updates `last_re_engagement_sent` timestamp

#### Flutter Services
- `lib/services/activity_service.dart`
  - Tracks and updates user activity
  - Calculates days since last activity

#### Documentation
- `RE_ENGAGEMENT_DEPLOYMENT.md` - Deployment guide
- `RE_ENGAGEMENT_SYSTEM.md` - This file

### Files Modified

#### Models
- `lib/models/user_profile.dart`
  - Added `lastAppActivity`, `reEngagementEnabled`, `lastReEngagementSent` fields

#### Services
- `lib/services/notification_service.dart`
  - Added deep linking callback for notification clicks
  - Handles `chat_id` from notification data

#### Providers
- `lib/providers/auth_provider.dart`
  - Links OneSignal external user ID on login
  - Clears external user ID on logout

- `lib/providers/chat_provider.dart`
  - Tracks activity when users send messages

#### UI
- `lib/main.dart`
  - Tracks app lifecycle (foreground/background)
  - Updates activity on app open

- `lib/ui/chat_list_page.dart`
  - Sets up notification deep linking callback
  - Navigates to specific chat when notification is tapped

## How It Works

### Activity Tracking Flow

1. **App Opens**
   - `main.dart` detects app lifecycle change
   - Calls `ActivityService.updateLastActivity()`
   - Updates `user_profiles.last_app_activity` in database

2. **User Sends Message**
   - `ChatProvider.sendUserMessage()` is called
   - Calls `ActivityService.updateLastActivity()`
   - Updates activity timestamp

3. **User Logs In**
   - `AuthProvider` links OneSignal external user ID
   - Allows targeted notifications by Supabase user ID

### Re-engagement Flow

1. **Cron Job Triggers** (Daily at 10 AM UTC)
   - Supabase cron job calls Edge Function via HTTP

2. **Edge Function Executes**
   - Queries users with `last_app_activity` older than 7 days
   - Filters users with `re_engagement_enabled = true`
   - Filters users who haven't received notification in last 7 days

3. **For Each Inactive User**
   - Finds most recent chat (by `last_message_time` or `created_at`)
   - Selects random notification template
   - Sends OneSignal notification with:
     - Personalized message with AI chat name
     - `chat_id` for deep linking
     - `type: 're_engagement'` identifier

4. **Updates Database**
   - Sets `last_re_engagement_sent` timestamp
   - Prevents duplicate notifications

### Notification Click Flow

1. **User Taps Notification**
   - OneSignal triggers click handler
   - `NotificationService` extracts `chat_id` from notification data

2. **Deep Linking**
   - Calls `onNotificationChatTap` callback
   - `ChatListPage` navigates to specific chat
   - Opens `ChatPage` with the chat ID

## Configuration

### Default Settings

- **Inactivity Threshold**: 7 days
- **Notification Frequency**: Max once per 7 days per user
- **Default Enabled**: `true` (users can opt-out)
- **Schedule**: Daily at 10:00 AM UTC

### Customizing Settings

#### Change Inactivity Threshold

Edit the Edge Function in Supabase Dashboard:
```typescript
const INACTIVITY_DAYS = 7 // Change this value
```

#### Change Notification Frequency

Edit the Edge Function:
```typescript
const MIN_NOTIFICATION_INTERVAL_DAYS = 7 // Change this value
```

#### Change Schedule

Edit the cron job in Supabase Dashboard → Database → Cron Jobs:
- Current: `0 10 * * *` (10 AM UTC daily)
- Use cron syntax or natural language

### Notification Messages

Notification templates are defined in the Edge Function:
```typescript
const NOTIFICATION_TEMPLATES = [
  (aiName: string) => `Continue your conversation with ${aiName}`,
  (aiName: string) => `${aiName} is waiting for you!`,
  (aiName: string) => `It's been a while! ${aiName} misses you`,
  (aiName: string) => `Pick up where you left off with ${aiName}`,
]
```

To add/change templates, edit the Edge Function in Supabase Dashboard.

## Database Schema

### user_profiles Table

```sql
-- Activity tracking
last_app_activity TIMESTAMPTZ          -- Last time user used the app
re_engagement_enabled BOOLEAN DEFAULT true  -- User opt-out preference
last_re_engagement_sent TIMESTAMPTZ   -- Last notification timestamp
```

### Indexes

```sql
-- For efficient inactive user queries
CREATE INDEX idx_user_profiles_last_app_activity 
ON user_profiles(last_app_activity) 
WHERE last_app_activity IS NOT NULL;

-- For filtering by preferences
CREATE INDEX idx_user_profiles_re_engagement_enabled 
ON user_profiles(re_engagement_enabled) 
WHERE re_engagement_enabled = true;
```

## Environment Variables

### Supabase Secrets (Edge Function)

Set in Supabase Dashboard → Edge Functions → Secrets:

- `ONESIGNAL_APP_ID` - Your OneSignal App ID
- `ONESIGNAL_REST_API_KEY` - Your OneSignal REST API Key

### Flutter App (.env)

- `ONESIGNAL_APP_ID` - Already configured for push notifications

## Monitoring & Debugging

### Check User Activity

Query in Supabase SQL Editor:
```sql
SELECT 
  id,
  display_name,
  last_app_activity,
  re_engagement_enabled,
  last_re_engagement_sent,
  CASE 
    WHEN last_app_activity IS NULL THEN 'Never'
    WHEN last_app_activity < NOW() - INTERVAL '7 days' THEN 'Inactive'
    ELSE 'Active'
  END as status
FROM user_profiles
ORDER BY last_app_activity DESC NULLS LAST;
```

### View Cron Job Logs

1. Go to Supabase Dashboard → Database → Cron Jobs
2. Click on `send-reengagement-notifications`
3. View execution history and logs

### View Edge Function Logs

1. Go to Supabase Dashboard → Edge Functions
2. Click on `send-reengagement-notifications`
3. Click "Logs" tab
4. View real-time execution logs

### Test Edge Function Manually

1. Go to Supabase Dashboard → Edge Functions
2. Click on `send-reengagement-notifications`
3. Click "Invoke function"
4. Check logs for results

Or use curl:
```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-reengagement-notifications \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

## User Preferences

### Opt-Out

Users can opt-out of re-engagement notifications by setting `re_engagement_enabled = false`:

```sql
UPDATE user_profiles 
SET re_engagement_enabled = false 
WHERE id = 'user_id_here';
```

### Opt-In

Users can opt back in:

```sql
UPDATE user_profiles 
SET re_engagement_enabled = true 
WHERE id = 'user_id_here';
```

## Troubleshooting

### Notifications Not Sending

1. **Check OneSignal Configuration**
   - Verify `ONESIGNAL_APP_ID` and `ONESIGNAL_REST_API_KEY` are set in Supabase secrets
   - Check OneSignal dashboard for delivery status

2. **Check User Eligibility**
   - User must have `last_app_activity` older than 7 days
   - User must have `re_engagement_enabled = true`
   - User must not have received notification in last 7 days

3. **Check Edge Function Logs**
   - Look for errors in Supabase Dashboard → Edge Functions → Logs
   - Check for OneSignal API errors

4. **Check Cron Job**
   - Verify cron job is active and scheduled correctly
   - Check cron job execution logs

### Users Not Receiving Notifications

1. **Check OneSignal Setup**
   - Verify OneSignal is initialized in the app
   - Check that users have granted notification permissions
   - Verify external user ID is set (happens on login)

2. **Check OneSignal Dashboard**
   - Go to OneSignal Dashboard → Audience
   - Verify users are registered
   - Check notification delivery status

### Deep Linking Not Working

1. **Check Notification Data**
   - Verify `chat_id` is included in notification data
   - Check notification click handler is set up

2. **Check Navigation**
   - Verify `onNotificationChatTap` callback is set in `ChatListPage`
   - Check that chat exists when notification is tapped

## Disabling the System

### Temporarily Disable

Disable the cron job:
```sql
SELECT cron.unschedule('send-reengagement-notifications');
```

Re-enable:
```sql
-- Recreate the cron job (see supabase_migration_add_reengagement_cron.sql)
```

### Permanently Disable for All Users

```sql
UPDATE user_profiles SET re_engagement_enabled = false;
```

## Maintenance

### Regular Tasks

1. **Monitor Logs Weekly**
   - Check Edge Function logs for errors
   - Review notification delivery rates
   - Check for any failed notifications

2. **Review User Activity**
   - Query inactive users periodically
   - Adjust thresholds if needed

3. **Update Notification Messages**
   - Refresh templates periodically
   - A/B test different messages

### Updating the Edge Function

1. Edit function in Supabase Dashboard → Edge Functions
2. Or update local file and redeploy
3. Test manually before relying on cron

## Best Practices

1. **Respect User Preferences**
   - Always check `re_engagement_enabled` before sending
   - Make opt-out easy for users

2. **Frequency Limits**
   - Don't send too frequently (current: max once per 7 days)
   - Adjust based on user feedback

3. **Personalization**
   - Always reference specific AI chats
   - Use varied message templates

4. **Monitoring**
   - Regularly check logs
   - Monitor delivery rates
   - Track user engagement after notifications

## Future Enhancements

Potential improvements:

- [ ] User-configurable notification preferences
- [ ] Different thresholds for different user segments
- [ ] A/B testing for notification messages
- [ ] Analytics dashboard for re-engagement metrics
- [ ] Smart timing (send at user's active hours)
- [ ] Multiple notification types (feature announcements, tips, etc.)

## Support

For issues or questions:
1. Check logs in Supabase Dashboard
2. Review this documentation
3. Check `RE_ENGAGEMENT_DEPLOYMENT.md` for deployment details

---

**Last Updated**: Implementation completed
**Status**: ✅ Fully deployed and operational

