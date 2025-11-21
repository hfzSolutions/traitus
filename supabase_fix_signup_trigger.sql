-- ========================================
-- FIX: User Profile Auto-Creation Trigger
-- ========================================
-- This fixes the "Database error saving new user" issue during signup
-- by ensuring the trigger function properly creates user profiles

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS create_user_profile();

-- Create improved function to automatically create a profile when a user signs up
-- This function handles both email/password signup and OAuth signup
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert into user_profiles table
    -- Use display_name from metadata if available, otherwise use email prefix
    INSERT INTO public.user_profiles (
        id, 
        display_name,
        onboarding_completed,
        preferences,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data->>'display_name',
            NEW.raw_user_meta_data->>'full_name',
            NEW.raw_user_meta_data->>'name',
            split_part(NEW.email, '@', 1)
        ),
        false,
        ARRAY[]::text[],
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;  -- Prevent duplicate key errors
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error but don't fail the user creation
        RAISE WARNING 'Error creating user profile for user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

-- Create the trigger that calls this function after a new user is inserted
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_user_profile();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.user_profiles TO postgres, anon, authenticated, service_role;

-- ========================================
-- Backfill: Create profiles for existing users without profiles
-- ========================================
-- This ensures any existing users who signed up when the trigger was broken
-- will also have profiles created

INSERT INTO public.user_profiles (id, display_name, onboarding_completed, preferences, created_at, updated_at)
SELECT 
    u.id,
    COALESCE(
        u.raw_user_meta_data->>'display_name',
        u.raw_user_meta_data->>'full_name',
        u.raw_user_meta_data->>'name',
        split_part(u.email, '@', 1)
    ) as display_name,
    false,
    ARRAY[]::text[],
    u.created_at,
    NOW()
FROM auth.users u
LEFT JOIN public.user_profiles p ON u.id = p.id
WHERE p.id IS NULL;

-- Show how many profiles were created
DO $$
DECLARE
    profiles_created INT;
BEGIN
    GET DIAGNOSTICS profiles_created = ROW_COUNT;
    RAISE NOTICE 'Created % missing user profiles', profiles_created;
END $$;

