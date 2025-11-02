-- Add onboarding fields to user_profiles table
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS preferences TEXT[] DEFAULT '{}';

-- Update existing users to have onboarding_completed set to true
-- (assuming they've already been using the app)
UPDATE user_profiles
SET onboarding_completed = true
WHERE onboarding_completed IS NULL OR onboarding_completed = false;

-- Create index for faster queries on onboarding_completed
CREATE INDEX IF NOT EXISTS idx_user_profiles_onboarding 
ON user_profiles(onboarding_completed);

