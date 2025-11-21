-- ========================================
-- FIX: cleanup_user_data function causing deletion errors
-- ========================================
-- The cleanup_user_data function is trying to delete from unqualified table names
-- which causes "relation chats does not exist" errors.
--
-- Since we're adding CASCADE to foreign keys, this function is actually redundant.
-- However, we'll fix it to use qualified table names and add safety checks.

-- ========================================
-- STEP 1: Drop the problematic trigger first
-- ========================================
DROP TRIGGER IF EXISTS cleanup_user_data_trigger ON auth.users;

-- ========================================
-- STEP 2: Fix the cleanup_user_data function
-- ========================================
-- Option A: Remove the manual deletions (recommended since CASCADE handles it)
-- Option B: Fix it to use qualified table names and add safety checks

-- We'll do Option B to be safe, but note that with CASCADE foreign keys,
-- the manual deletions are redundant.

CREATE OR REPLACE FUNCTION cleanup_user_data()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- With CASCADE foreign keys, these deletions are redundant,
    -- but we'll keep them as a safety net with proper error handling
    
    -- Delete all user's chats (using qualified table name)
    -- Note: This will cascade to messages automatically if CASCADE is set
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chats') THEN
            DELETE FROM public.chats WHERE user_id = OLD.id;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Error deleting chats for user %: %', OLD.id, SQLERRM;
    END;
    
    -- Delete all user's notes (using qualified table name)
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notes') THEN
            DELETE FROM public.notes WHERE user_id = OLD.id;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Error deleting notes for user %: %', OLD.id, SQLERRM;
    END;
    
    RETURN OLD;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the deletion
        RAISE WARNING 'Error in cleanup_user_data for user %: %', OLD.id, SQLERRM;
        RETURN OLD;
END;
$$;

-- ========================================
-- STEP 3: Recreate the trigger (if you want to keep it)
-- ========================================
-- NOTE: With CASCADE foreign keys, this trigger is actually redundant.
-- The CASCADE will automatically delete chats and notes when the user is deleted.
-- However, if you want to keep it as a safety net, uncomment below:

-- CREATE TRIGGER cleanup_user_data_trigger
--   BEFORE DELETE ON auth.users
--   FOR EACH ROW
--   EXECUTE FUNCTION cleanup_user_data();

-- ========================================
-- RECOMMENDED: Remove the function entirely
-- ========================================
-- Since CASCADE foreign keys handle deletion automatically, you can
-- safely remove this function and trigger. Uncomment to remove:

-- DROP FUNCTION IF EXISTS cleanup_user_data() CASCADE;

-- ========================================
-- SUMMARY
-- ========================================
-- This migration:
-- 1. Drops the problematic trigger
-- 2. Fixes the function to use qualified table names (public.chats, public.notes)
-- 3. Adds safety checks for table existence
-- 4. Adds proper error handling
--
-- However, once you run the CASCADE migration, this function becomes redundant.
-- You can either:
-- - Keep it as a safety net (recreate the trigger)
-- - Remove it entirely (drop the function)
--
-- The CASCADE foreign keys will handle all deletions automatically.

