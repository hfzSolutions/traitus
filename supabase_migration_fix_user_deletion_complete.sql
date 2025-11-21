-- ========================================
-- COMPLETE FIX: User Deletion Error
-- ========================================
-- This migration comprehensively fixes user deletion issues by:
-- 1. Creating missing tables if they don't exist
-- 2. Removing orphaned constraints and triggers
-- 3. Ensuring all foreign keys have CASCADE
-- 4. Making all operations safe and idempotent
--
-- Run this in your Supabase SQL Editor to fix the deletion error.

-- ========================================
-- STEP 1: Create missing tables if they don't exist
-- ========================================

-- Create chats table if missing
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chats') THEN
    CREATE TABLE public.chats (
      id uuid NOT NULL DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL,
      name text NOT NULL,
      short_description text NOT NULL,
      last_message text,
      last_message_time timestamp with time zone,
      created_at timestamp with time zone NOT NULL DEFAULT now(),
      is_pinned boolean DEFAULT false,
      sort_order integer DEFAULT 0,
      avatar_url text,
      response_tone text DEFAULT 'friendly'::text,
      response_length text DEFAULT 'balanced'::text,
      writing_style text DEFAULT 'simple'::text,
      use_emojis boolean DEFAULT false,
      system_prompt text NOT NULL DEFAULT 'You are a helpful AI assistant.'::text,
      last_read_at timestamp with time zone,
      model text,
      CONSTRAINT chats_pkey PRIMARY KEY (id)
    );
    RAISE NOTICE 'Created missing chats table';
  END IF;
END $$;

-- Create messages table if missing
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'messages') THEN
    CREATE TABLE public.messages (
      id uuid NOT NULL DEFAULT gen_random_uuid(),
      chat_id uuid NOT NULL,
      user_id uuid NOT NULL,
      role text NOT NULL CHECK (role = ANY (ARRAY['user'::text, 'assistant'::text, 'system'::text])),
      content text NOT NULL,
      created_at timestamp with time zone NOT NULL DEFAULT now(),
      is_pending boolean DEFAULT false,
      has_error boolean DEFAULT false,
      image_urls text[],
      generated_images text[],
      model text,
      CONSTRAINT messages_pkey PRIMARY KEY (id)
    );
    RAISE NOTICE 'Created missing messages table';
  END IF;
END $$;

-- ========================================
-- STEP 2: Remove ALL orphaned foreign key constraints
-- ========================================
-- This removes any constraints that reference non-existent tables
DO $$
DECLARE
  constraint_record RECORD;
BEGIN
  FOR constraint_record IN
    SELECT 
      tc.table_schema,
      tc.table_name,
      tc.constraint_name,
      ccu.table_name AS referenced_table
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu
      ON tc.constraint_name = ccu.constraint_name
      AND tc.table_schema = ccu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema = 'public'
      AND ccu.table_schema = 'public'
      AND NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = ccu.table_name
      )
  LOOP
    BEGIN
      EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I', 
        constraint_record.table_schema,
        constraint_record.table_name, 
        constraint_record.constraint_name);
      RAISE NOTICE 'Dropped orphaned constraint % from table %.% (referenced non-existent table %)', 
        constraint_record.constraint_name,
        constraint_record.table_schema,
        constraint_record.table_name,
        constraint_record.referenced_table;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Could not drop constraint % from table %.%: %', 
          constraint_record.constraint_name,
          constraint_record.table_schema,
          constraint_record.table_name,
          SQLERRM;
    END;
  END LOOP;
END $$;

-- ========================================
-- STEP 3: Fix ALL foreign keys to have CASCADE
-- ========================================

-- Fix user_profiles
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_profiles') THEN
    -- Drop existing constraint
    ALTER TABLE public.user_profiles
      DROP CONSTRAINT IF EXISTS user_profiles_id_fkey;
    
    -- Add CASCADE constraint
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_id_fkey
        FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Fixed user_profiles foreign key';
  END IF;
END $$;

-- Fix user_entitlements
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_entitlements') THEN
    ALTER TABLE public.user_entitlements
      DROP CONSTRAINT IF EXISTS user_entitlements_user_id_fkey;
    
    ALTER TABLE public.user_entitlements
      ADD CONSTRAINT user_entitlements_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Fixed user_entitlements foreign key';
  END IF;
END $$;

-- Fix notes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notes') THEN
    ALTER TABLE public.notes
      DROP CONSTRAINT IF EXISTS notes_user_id_fkey;
    
    ALTER TABLE public.notes
      ADD CONSTRAINT notes_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Fixed notes foreign key';
  END IF;
END $$;

-- Fix note_sections (cascade when notes are deleted)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'note_sections') THEN
    ALTER TABLE public.note_sections
      DROP CONSTRAINT IF EXISTS note_sections_note_id_fkey;
    
    -- Only add constraint if notes table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notes') THEN
      ALTER TABLE public.note_sections
        ADD CONSTRAINT note_sections_note_id_fkey
          FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;
    END IF;
    
    RAISE NOTICE 'Fixed note_sections foreign key';
  END IF;
END $$;

-- Fix chats (only if table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chats') THEN
    ALTER TABLE public.chats
      DROP CONSTRAINT IF EXISTS chats_user_id_fkey;
    
    ALTER TABLE public.chats
      ADD CONSTRAINT chats_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Fixed chats foreign key';
  END IF;
END $$;

-- Fix messages (only if table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'messages') THEN
    -- Fix user_id foreign key
    ALTER TABLE public.messages
      DROP CONSTRAINT IF EXISTS messages_user_id_fkey;
    
    ALTER TABLE public.messages
      ADD CONSTRAINT messages_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    -- Fix chat_id foreign key (only if chats table exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chats') THEN
      ALTER TABLE public.messages
        DROP CONSTRAINT IF EXISTS messages_chat_id_fkey;
      
      ALTER TABLE public.messages
        ADD CONSTRAINT messages_chat_id_fkey
          FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON DELETE CASCADE;
    END IF;
    
    RAISE NOTICE 'Fixed messages foreign keys';
  END IF;
END $$;

-- ========================================
-- STEP 4: Fix or remove problematic triggers
-- ========================================

-- Fix cleanup_user_data function (the one causing the error!)
-- This function uses unqualified table names which causes schema lookup issues
DROP TRIGGER IF EXISTS cleanup_user_data_trigger ON auth.users;

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

-- Recreate the trigger (optional - CASCADE handles deletion, but keeping as safety net)
-- If you want to rely solely on CASCADE, comment out the trigger creation below
CREATE TRIGGER cleanup_user_data_trigger
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION cleanup_user_data();

-- Update cleanup_user_storage function to handle missing tables gracefully
CREATE OR REPLACE FUNCTION cleanup_user_storage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_id_text TEXT;
BEGIN
  user_id_text := OLD.id::TEXT;
  
  -- Delete user avatars from user-avatars bucket (if bucket exists)
  BEGIN
    DELETE FROM storage.objects
    WHERE bucket_id = 'user-avatars'
      AND (storage.foldername(name))[1] = user_id_text;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Error deleting user-avatars for user %: %', user_id_text, SQLERRM;
  END;
  
  -- Delete chat avatars from chat-avatars bucket (if bucket exists)
  BEGIN
    DELETE FROM storage.objects
    WHERE bucket_id = 'chat-avatars'
      AND (storage.foldername(name))[1] = user_id_text;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Error deleting chat-avatars for user %: %', user_id_text, SQLERRM;
  END;
  
  -- Delete chat images from chat-images bucket (if bucket exists)
  BEGIN
    DELETE FROM storage.objects
    WHERE bucket_id = 'chat-images'
      AND (storage.foldername(name))[1] = user_id_text;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Error deleting chat-images for user %: %', user_id_text, SQLERRM;
  END;
  
  RETURN OLD;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the deletion
    RAISE WARNING 'Error in cleanup_user_storage for user %: %', user_id_text, SQLERRM;
    RETURN OLD;
END;
$$;

-- Recreate trigger (drop and recreate to ensure it's correct)
DROP TRIGGER IF EXISTS cleanup_user_storage_trigger ON auth.users;
CREATE TRIGGER cleanup_user_storage_trigger
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION cleanup_user_storage();

-- ========================================
-- STEP 5: Verify all foreign keys have CASCADE
-- ========================================
-- This query will show you all foreign keys and their delete rules
-- Uncomment to run:
/*
SELECT
  tc.table_schema,
  tc.table_name,
  kcu.column_name,
  ccu.table_schema AS foreign_table_schema,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
  ON rc.constraint_name = tc.constraint_name
  AND rc.constraint_schema = tc.table_schema
WHERE ccu.table_name = 'users'
  AND ccu.table_schema = 'auth'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name;
*/

-- ========================================
-- SUMMARY
-- ========================================
-- After running this migration:
-- 1. All missing tables will be created
-- 2. All orphaned constraints will be removed
-- 3. All foreign keys will have ON DELETE CASCADE
-- 4. The cleanup trigger will handle errors gracefully
-- 5. User deletion should work without errors

DO $$
BEGIN
  RAISE NOTICE 'Migration completed successfully! User deletion should now work.';
END $$;

