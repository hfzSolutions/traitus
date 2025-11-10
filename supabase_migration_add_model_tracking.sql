-- Migration: Add model tracking to messages table
-- This migration adds the model field back to track which model was actually used
-- This is important when using openrouter/auto which selects different models

-- ========================================
-- Add model field to messages table
-- ========================================
ALTER TABLE messages ADD COLUMN IF NOT EXISTS model TEXT;

-- Create index for faster queries on model
CREATE INDEX IF NOT EXISTS idx_messages_model ON messages(model);

-- ========================================
-- Notes:
-- - The model field tracks the actual model used for each message
-- - This is especially important when using openrouter/auto
-- - The app uses OPENROUTER_MODEL from env, but the actual model may vary
-- - Only assistant messages will have the model field populated

