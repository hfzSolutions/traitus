-- ========================================
-- QUICK FIX: cleanup_user_data function
-- ========================================
-- This fixes the immediate error by updating the function to use qualified table names
-- Run this FIRST, then run the complete migration for CASCADE foreign keys

-- Fix the cleanup_user_data function to use qualified table names
CREATE OR REPLACE FUNCTION cleanup_user_data()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Use qualified table names (public.chats, public.notes) to avoid schema lookup issues
    
    -- Delete all user's chats
    BEGIN
        DELETE FROM public.chats WHERE user_id = OLD.id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Error deleting chats for user %: %', OLD.id, SQLERRM;
    END;
    
    -- Delete all user's notes
    BEGIN
        DELETE FROM public.notes WHERE user_id = OLD.id;
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

-- Ensure the trigger exists
DROP TRIGGER IF EXISTS cleanup_user_data_trigger ON auth.users;
CREATE TRIGGER cleanup_user_data_trigger
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION cleanup_user_data();

