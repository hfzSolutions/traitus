-- Migration: Add response style preferences to chats table
-- This allows users to customize how the AI responds in a user-friendly way

-- Add response style columns to chats table
ALTER TABLE chats
ADD COLUMN IF NOT EXISTS response_tone TEXT DEFAULT 'friendly',
ADD COLUMN IF NOT EXISTS response_length TEXT DEFAULT 'balanced',
ADD COLUMN IF NOT EXISTS writing_style TEXT DEFAULT 'simple',
ADD COLUMN IF NOT EXISTS use_emojis BOOLEAN DEFAULT FALSE;

-- Add comments to describe the columns
COMMENT ON COLUMN chats.response_tone IS 'AI response tone: friendly, professional, casual, formal, enthusiastic';
COMMENT ON COLUMN chats.response_length IS 'Response length preference: brief, balanced, detailed';
COMMENT ON COLUMN chats.writing_style IS 'Writing style: simple, technical, creative, analytical';
COMMENT ON COLUMN chats.use_emojis IS 'Whether to use emojis in responses';

-- Update existing chats with default values (already handled by DEFAULT in ALTER TABLE)
-- But we can verify by running an UPDATE if needed
UPDATE chats
SET 
  response_tone = COALESCE(response_tone, 'friendly'),
  response_length = COALESCE(response_length, 'balanced'),
  writing_style = COALESCE(writing_style, 'simple'),
  use_emojis = COALESCE(use_emojis, FALSE)
WHERE response_tone IS NULL 
   OR response_length IS NULL 
   OR writing_style IS NULL 
   OR use_emojis IS NULL;

