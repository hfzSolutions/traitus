# Re-engagement System Deployment Guide

This guide explains how to deploy the re-engagement notification system to your **online/hosted Supabase project**.

## Prerequisites

- Supabase project (hosted/cloud)
- OneSignal account with App ID and REST API Key
- Supabase CLI installed (optional, for Edge Functions)

## Step 1: Run Database Migration

1. Go to your Supabase Dashboard: https://app.supabase.com
2. Select your project
3. Navigate to **SQL Editor**
4. Open the file `supabase_migration_add_user_activity_tracking.sql`
5. Copy and paste the entire SQL into the SQL Editor
6. Click **Run** to execute the migration

This will add the necessary columns to your `user_profiles` table:
- `last_app_activity` - Tracks when user last used the app
- `re_engagement_enabled` - Allows users to opt-out (default: true)
- `last_re_engagement_sent` - Tracks when we last sent a notification

## Step 2: Deploy Edge Function

You have two options to deploy the Edge Function:

### Option A: Using Supabase Dashboard (Recommended)

1. Go to Supabase Dashboard → **Edge Functions**
2. Click **Create a new function**
3. Name it: `send-reengagement-notifications`
4. Copy the contents of `supabase/functions/send-reengagement-notifications/index.ts`
5. Paste it into the function editor
6. Click **Deploy**

### Option B: Using Supabase CLI

If you have Supabase CLI installed:

```bash
# Login to Supabase (if not already logged in)
supabase login

# Link to your project (if not already linked)
supabase link --project-ref YOUR_PROJECT_REF

# Deploy the function
supabase functions deploy send-reengagement-notifications
```

## Step 3: Set Environment Variables (Secrets)

The Edge Function needs access to OneSignal credentials. Set these as secrets in Supabase:

1. Go to Supabase Dashboard → **Project Settings** → **Edge Functions** → **Secrets**
2. Add the following secrets:

   - **ONESIGNAL_APP_ID**: Your OneSignal App ID
   - **ONESIGNAL_REST_API_KEY**: Your OneSignal REST API Key

   To get your OneSignal REST API Key:
   - Go to OneSignal Dashboard → **Settings** → **Keys & IDs**
   - Copy the **REST API Key**

3. Click **Save** for each secret

**Note**: The Edge Function also needs access to Supabase service role key, but this is automatically available in the Edge Function environment.

## Step 4: Set Up Scheduled Cron Job

Supabase provides built-in cron scheduling. You can set it up in two ways:

### Option A: Using Supabase Dashboard (Easiest)

1. Go to Supabase Dashboard → **Database** → **Cron Jobs**
2. Click **New Cron Job**
3. Configure:
   - **Name**: `send-reengagement-notifications`
   - **Schedule**: `0 10 * * *` (runs daily at 10:00 AM UTC)
   - **Command**: 
     ```sql
     SELECT
       net.http_post(
         url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-reengagement-notifications',
         headers := jsonb_build_object(
           'Content-Type', 'application/json',
           'Authorization', 'Bearer YOUR_ANON_KEY'
         ),
         body := '{}'::jsonb
       ) AS request_id;
     ```
   - Replace `YOUR_PROJECT_REF` with your project reference (found in project URL)
   - Replace `YOUR_ANON_KEY` with your anon/public key (found in Settings → API)

4. Click **Create**

### Option B: Using SQL (Alternative)

1. Go to Supabase Dashboard → **SQL Editor**
2. Run this SQL (replace placeholders):

```sql
SELECT cron.schedule(
  'send-reengagement-notifications',
  '0 10 * * *',
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-reengagement-notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_ANON_KEY'
      ),
      body := '{}'::jsonb
    ) AS request_id;
  $$
);
```

**To find your values:**
- **Project Ref**: Found in your Supabase project URL: `https://YOUR_PROJECT_REF.supabase.co`
- **Anon Key**: Go to **Settings** → **API** → Copy **anon public** key

## Step 5: Test the Function

Before relying on the cron job, test the function manually:

1. Go to Supabase Dashboard → **Edge Functions** → `send-reengagement-notifications`
2. Click **Invoke function**
3. Check the logs to see if it runs successfully
4. Verify that notifications are sent to test users

Or use curl:

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-reengagement-notifications \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Step 6: Verify OneSignal Integration

1. Make sure your Flutter app has OneSignal configured (already done)
2. Verify that users are linked to OneSignal:
   - When users log in, their Supabase user ID should be set as OneSignal external user ID
   - This happens automatically in `AuthProvider`

## Configuration

### Default Settings

- **Inactivity threshold**: 7 days (users inactive for 7+ days get notifications)
- **Notification frequency**: Max once per 7 days per user
- **Default enabled**: `true` (users can opt-out via `re_engagement_enabled`)

### Customizing the Threshold

To change the inactivity threshold, edit the Edge Function:

1. Open `supabase/functions/send-reengagement-notifications/index.ts`
2. Find: `const INACTIVITY_DAYS = 7`
3. Change to your desired number of days
4. Redeploy the function

## Monitoring

### View Cron Job Logs

1. Go to Supabase Dashboard → **Database** → **Cron Jobs**
2. Click on `send-reengagement-notifications`
3. View execution history and logs

### View Edge Function Logs

1. Go to Supabase Dashboard → **Edge Functions** → `send-reengagement-notifications`
2. Click **Logs** tab
3. View real-time logs and execution history

### Check User Activity

Query user activity in SQL Editor:

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

## Troubleshooting

### Function Not Running

1. Check Edge Function logs for errors
2. Verify secrets are set correctly
3. Check cron job is enabled and scheduled correctly
4. Verify OneSignal credentials are correct

### Notifications Not Sending

1. Verify OneSignal App ID and REST API Key are correct
2. Check that users have `re_engagement_enabled = true`
3. Verify users haven't received a notification in the last 7 days
4. Check OneSignal dashboard for delivery status

### Users Not Getting Notifications

1. Verify OneSignal is initialized in the app
2. Check that users have granted notification permissions
3. Verify external user ID is set (happens on login)
4. Check OneSignal dashboard → **Audience** to see if users are registered

## Disabling Re-engagement

To temporarily disable re-engagement for all users:

```sql
UPDATE user_profiles SET re_engagement_enabled = false;
```

To disable the cron job:

```sql
SELECT cron.unschedule('send-reengagement-notifications');
```

## Next Steps

1. ✅ Run database migration
2. ✅ Deploy Edge Function
3. ✅ Set environment variables/secrets
4. ✅ Set up cron job
5. ✅ Test the function
6. ✅ Monitor logs and adjust as needed

The system will automatically start sending re-engagement notifications to inactive users after deployment!

