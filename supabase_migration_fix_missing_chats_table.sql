-- ========================================
-- FIX: Handle missing chats table during user deletion
-- ========================================
-- This migration fixes the error: "relation 'chats' does not exist"
-- that occurs when trying to delete users from Supabase dashboard.
--
-- The issue happens when foreign key constraints or triggers reference
-- the 'chats' table, but the table doesn't exist in the database.

-- ========================================
-- 1. Check if chats table exists, create if missing
-- ========================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chats') THEN
    -- Create the chats table if it doesn't exist
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
  ELSE
    RAISE NOTICE 'Chats table already exists';
  END IF;
END $$;

-- ========================================
-- 2. Check if messages table exists, create if missing
-- ========================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'messages') THEN
    -- Create the messages table if it doesn't exist
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
  ELSE
    RAISE NOTICE 'Messages table already exists';
  END IF;
END $$;

-- ========================================
-- 3. Remove any orphaned foreign key constraints
-- ========================================
-- This removes constraints that reference non-existent tables
DO $$
DECLARE
  constraint_record RECORD;
BEGIN
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
      AND NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = ccu.table_name
      )
  LOOP
    BEGIN
      EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', 
        constraint_record.table_name, 
        constraint_record.constraint_name);
      RAISE NOTICE 'Dropped orphaned constraint % from table % (referenced non-existent table %)', 
        constraint_record.constraint_name, 
        constraint_record.table_name,
        constraint_record.referenced_table;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Could not drop constraint % from table %: %', 
          constraint_record.constraint_name, 
          constraint_record.table_name,
          SQLERRM;
    END;
  END LOOP;
END $$;

-- ========================================
-- 4. Now add proper foreign key constraints with CASCADE
-- ========================================
-- This ensures user deletion cascades properly

-- Fix chats foreign key
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chats') THEN
    ALTER TABLE public.chats
      DROP CONSTRAINT IF EXISTS chats_user_id_fkey;

    ALTER TABLE public.chats
      ADD CONSTRAINT chats_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Fixed chats foreign key constraint';
  END IF;
END $$;

-- Fix messages foreign keys
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
    
    RAISE NOTICE 'Fixed messages foreign key constraints';
  END IF;
END $$;

-- ========================================
-- 5. Enable RLS on tables if they exist
-- ========================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chats') THEN
    ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'messages') THEN
    ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- ========================================
-- Verification
-- ========================================
-- After running this migration, you should be able to delete users.
-- The migration will:
-- 1. Create the chats and messages tables if they don't exist
-- 2. Remove any orphaned constraints
-- 3. Add proper CASCADE foreign keys
-- 4. Enable RLS on the tables

