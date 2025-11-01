-- Migration: Add model field to messages table
-- Run this SQL in your Supabase SQL Editor if you already have an existing database

-- Add model column to messages table
ALTER TABLE messages ADD COLUMN IF NOT EXISTS model TEXT;

-- Optional: Add an index if you plan to query by model frequently
CREATE INDEX IF NOT EXISTS idx_messages_model ON messages(model);

-- Optional: Update existing messages to have a default model value
-- Uncomment and modify the following line if you want to set a default for existing messages
-- UPDATE messages SET model = 'anthropic/claude-3-sonnet' WHERE model IS NULL AND role = 'assistant';

