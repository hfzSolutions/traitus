-- Migration: Remove model-related fields and tables
-- This migration removes all model selection functionality
-- The app now uses OPENROUTER_MODEL from environment variable only

-- ========================================
-- 1. Remove model field from chats table
-- ========================================
ALTER TABLE chats DROP COLUMN IF EXISTS model;

-- ========================================
-- 2. Remove model field from messages table
-- ========================================
ALTER TABLE messages DROP COLUMN IF EXISTS model;

-- Remove model index if it exists
DROP INDEX IF EXISTS idx_messages_model;

-- ========================================
-- 3. Drop related triggers first (before dropping table)
-- ========================================
-- Drop trigger if models table exists (use DO block to avoid error if table doesn't exist)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'models') THEN
        DROP TRIGGER IF EXISTS t_models_updated ON models;
    END IF;
END $$;

-- ========================================
-- 4. Drop models table (if it exists)
-- ========================================
DROP TABLE IF EXISTS models CASCADE;

-- ========================================
-- Notes:
-- - The app now uses OPENROUTER_MODEL from .env file only
-- - No model selection UI or database storage needed
-- - All chats and messages will work with the single model from env
-- - This migration is safe to run even if models table doesn't exist

