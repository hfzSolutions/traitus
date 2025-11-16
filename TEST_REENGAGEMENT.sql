-- Test Re-engagement Notification
-- This SQL will make your user account appear inactive so you can test notifications
-- Replace 'YOUR_USER_ID' with your actual user ID from the user_profiles table

-- Option 1: Set last_app_activity to 8 days ago (will trigger notification)
UPDATE user_profiles
SET 
  last_app_activity = NOW() - INTERVAL '8 days',
  last_re_engagement_sent = NULL  -- Clear previous notification timestamp
WHERE id = 'YOUR_USER_ID';

-- Option 2: Set to 10 days ago (more clearly inactive)
UPDATE user_profiles
SET 
  last_app_activity = NOW() - INTERVAL '10 days',
  last_re_engagement_sent = NULL
WHERE id = 'YOUR_USER_ID';

-- Option 3: Set to exactly 7 days and 1 hour ago (just over threshold)
UPDATE user_profiles
SET 
  last_app_activity = NOW() - INTERVAL '7 days 1 hour',
  last_re_engagement_sent = NULL
WHERE id = 'YOUR_USER_ID';

-- To find your user ID, run this first:
-- SELECT id, display_name, last_app_activity, re_engagement_enabled 
-- FROM user_profiles;

-- After testing, reset your activity to current time:
-- UPDATE user_profiles
-- SET last_app_activity = NOW()
-- WHERE id = 'YOUR_USER_ID';

