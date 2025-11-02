-- Add date of birth and preferred language to user_profiles table
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS date_of_birth DATE,
ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(10) DEFAULT 'en';

-- Create index for date queries (e.g., birthday notifications)
CREATE INDEX IF NOT EXISTS idx_user_profiles_dob 
ON user_profiles(date_of_birth);

-- Create index for language filtering
CREATE INDEX IF NOT EXISTS idx_user_profiles_language 
ON user_profiles(preferred_language);

-- Add comment for documentation
COMMENT ON COLUMN user_profiles.date_of_birth IS 'User date of birth for age calculation and personalization';
COMMENT ON COLUMN user_profiles.preferred_language IS 'Preferred language code for AI responses (ISO 639-1)';

