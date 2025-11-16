-- Migration: Add User Activity Tracking for Re-engagement
-- This migration adds columns to track user activity and re-engagement preferences

-- Add last_app_activity to track when user last used the app
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS last_app_activity TIMESTAMPTZ;

-- Add re_engagement_enabled to allow users to opt-out of re-engagement notifications
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS re_engagement_enabled BOOLEAN DEFAULT true;

-- Add last_re_engagement_sent to track when we last sent a re-engagement notification
-- This prevents spamming users with too many notifications
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS last_re_engagement_sent TIMESTAMPTZ;

-- Backfill existing users with current timestamp so they don't immediately get notifications
UPDATE user_profiles 
SET last_app_activity = COALESCE(last_app_activity, now())
WHERE last_app_activity IS NULL;

-- Create index for efficient queries when finding inactive users
CREATE INDEX IF NOT EXISTS idx_user_profiles_last_app_activity 
ON user_profiles(last_app_activity) 
WHERE last_app_activity IS NOT NULL;

-- Create index for efficient queries when filtering by re-engagement preferences
CREATE INDEX IF NOT EXISTS idx_user_profiles_re_engagement_enabled 
ON user_profiles(re_engagement_enabled) 
WHERE re_engagement_enabled = true;

