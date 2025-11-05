-- Migration: Add system_prompt column and rename description to short_description
-- This separates user-facing descriptions from AI system prompts
-- Run this SQL in your Supabase SQL Editor

-- Add system_prompt column (nullable initially for migration)
ALTER TABLE chats
ADD COLUMN IF NOT EXISTS system_prompt TEXT;

-- Rename description to short_description
ALTER TABLE chats
RENAME COLUMN description TO short_description;

-- Migrate existing data: copy short_description to system_prompt if system_prompt is null
-- This ensures backward compatibility - existing descriptions become both short description and system prompt
UPDATE chats
SET system_prompt = short_description
WHERE system_prompt IS NULL;

-- Make system_prompt NOT NULL after migration
ALTER TABLE chats
ALTER COLUMN system_prompt SET NOT NULL;

-- Add default fallback for system_prompt (shouldn't be needed after migration, but good safety)
ALTER TABLE chats
ALTER COLUMN system_prompt SET DEFAULT 'You are a helpful AI assistant.';

-- Add comments to describe the columns
COMMENT ON COLUMN chats.short_description IS 'User-facing short description shown under AI name in UI';
COMMENT ON COLUMN chats.system_prompt IS 'AI system prompt (not shown to users, used for AI behavior)';

