-- ========================================
-- FIX: Add CASCADE to all foreign keys for user deletion
-- ========================================
-- This migration fixes the "Database error deleting user" issue
-- by adding ON DELETE CASCADE to all foreign keys that reference auth.users
--
-- After running this, you'll be able to delete users from the Supabase dashboard
-- and all related data will be automatically deleted.

-- ========================================
-- 1. Fix user_profiles foreign key
-- ========================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_profiles') THEN
    ALTER TABLE public.user_profiles
      DROP CONSTRAINT IF EXISTS user_profiles_id_fkey;

    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_id_fkey
        FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ========================================
-- 2. Fix user_entitlements foreign key
-- ========================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_entitlements') THEN
    ALTER TABLE public.user_entitlements
      DROP CONSTRAINT IF EXISTS user_entitlements_user_id_fkey;

    ALTER TABLE public.user_entitlements
      ADD CONSTRAINT user_entitlements_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ========================================
-- 3. Fix notes foreign key
-- ========================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notes') THEN
    ALTER TABLE public.notes
      DROP CONSTRAINT IF EXISTS notes_user_id_fkey;

    ALTER TABLE public.notes
      ADD CONSTRAINT notes_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ========================================
-- 4. Fix chats foreign key (only if table exists)
-- ========================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chats') THEN
    ALTER TABLE public.chats
      DROP CONSTRAINT IF EXISTS chats_user_id_fkey;

    ALTER TABLE public.chats
      ADD CONSTRAINT chats_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ========================================
-- 5. Fix messages foreign keys (only if table exists)
-- ========================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'messages') THEN
    -- First, fix the user_id foreign key
    ALTER TABLE public.messages
      DROP CONSTRAINT IF EXISTS messages_user_id_fkey;

    ALTER TABLE public.messages
      ADD CONSTRAINT messages_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

    -- Then, fix the chat_id foreign key (so when a chat is deleted, messages are deleted too)
    -- Only if chats table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chats') THEN
      ALTER TABLE public.messages
        DROP CONSTRAINT IF EXISTS messages_chat_id_fkey;

      ALTER TABLE public.messages
        ADD CONSTRAINT messages_chat_id_fkey
          FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

-- ========================================
-- 5.5. Clean up any orphaned foreign key constraints
-- ========================================
-- Remove any foreign key constraints that reference non-existent tables
DO $$
DECLARE
  constraint_record RECORD;
BEGIN
  -- Find and drop foreign key constraints that reference non-existent tables
  FOR constraint_record IN
    SELECT 
      tc.constraint_name,
      tc.table_name,
      ccu.table_name AS referenced_table
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu
      ON tc.constraint_name = ccu.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema = 'public'
      AND ccu.table_schema = 'public'
      AND (
        (ccu.table_name = 'chats' AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chats'))
        OR (ccu.table_name = 'messages' AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'messages'))
      )
  LOOP
    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', 
      constraint_record.table_name, 
      constraint_record.constraint_name);
    RAISE NOTICE 'Dropped orphaned constraint % from table %', 
      constraint_record.constraint_name, 
      constraint_record.table_name;
  END LOOP;
END $$;

-- ========================================
-- 6. Create function to clean up storage files when user is deleted
-- ========================================
-- This function will be called via a trigger to clean up storage files
CREATE OR REPLACE FUNCTION cleanup_user_storage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_id_text TEXT;
BEGIN
  user_id_text := OLD.id::TEXT;
  
  -- Delete user avatars from user-avatars bucket
  DELETE FROM storage.objects
  WHERE bucket_id = 'user-avatars'
    AND (storage.foldername(name))[1] = user_id_text;
  
  -- Delete chat avatars from chat-avatars bucket
  DELETE FROM storage.objects
  WHERE bucket_id = 'chat-avatars'
    AND (storage.foldername(name))[1] = user_id_text;
  
  -- Delete chat images from chat-images bucket
  DELETE FROM storage.objects
  WHERE bucket_id = 'chat-images'
    AND (storage.foldername(name))[1] = user_id_text;
  
  RETURN OLD;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the deletion
    RAISE WARNING 'Error cleaning up storage for user %: %', user_id_text, SQLERRM;
    RETURN OLD;
END;
$$;

-- Create trigger to clean up storage before user deletion
DROP TRIGGER IF EXISTS cleanup_user_storage_trigger ON auth.users;
CREATE TRIGGER cleanup_user_storage_trigger
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION cleanup_user_storage();

-- ========================================
-- Verification Queries
-- ========================================
-- Run these queries to verify the constraints are set up correctly:

-- Check all foreign keys referencing auth.users
-- SELECT
--   tc.table_name,
--   kcu.column_name,
--   ccu.table_name AS foreign_table_name,
--   ccu.column_name AS foreign_column_name,
--   rc.delete_rule
-- FROM information_schema.table_constraints AS tc
-- JOIN information_schema.key_column_usage AS kcu
--   ON tc.constraint_name = kcu.constraint_name
-- JOIN information_schema.constraint_column_usage AS ccu
--   ON ccu.constraint_name = tc.constraint_name
-- JOIN information_schema.referential_constraints AS rc
--   ON rc.constraint_name = tc.constraint_name
-- WHERE ccu.table_name = 'users'
--   AND ccu.table_schema = 'auth'
-- ORDER BY tc.table_name;

-- ========================================
-- What This Migration Does
-- ========================================
-- After running this migration, you'll be able to delete users from the Supabase dashboard.
-- The deletion will cascade through:
-- 1. Storage files -> deleted (user-avatars, chat-avatars, chat-images)
-- 2. user_profiles -> deleted
-- 3. user_entitlements -> deleted
-- 4. notes -> deleted
-- 5. chats -> deleted (which will also delete all messages in those chats)
-- 6. messages -> deleted (both directly and via chat deletion)

