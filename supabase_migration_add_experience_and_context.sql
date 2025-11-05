-- Add experience level and use context to user_profiles table
-- These fields help personalize AI assistant recommendations

ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS experience_level VARCHAR(20),
ADD COLUMN IF NOT EXISTS use_context VARCHAR(20);

-- Create indexes for filtering and analytics
CREATE INDEX IF NOT EXISTS idx_user_profiles_experience_level 
ON user_profiles(experience_level);

CREATE INDEX IF NOT EXISTS idx_user_profiles_use_context 
ON user_profiles(use_context);

-- Add comments for documentation
COMMENT ON COLUMN user_profiles.experience_level IS 'User experience level: beginner, intermediate, or advanced';
COMMENT ON COLUMN user_profiles.use_context IS 'Primary use context: work, personal, or both';

