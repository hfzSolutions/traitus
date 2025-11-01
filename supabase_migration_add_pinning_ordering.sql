-- Migration: Add pinning and ordering support to chats
-- Run this SQL in your Supabase SQL Editor

-- Add is_pinned and sort_order columns to chats table
ALTER TABLE chats 
ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

-- Create index for faster sorting queries
CREATE INDEX IF NOT EXISTS idx_chats_is_pinned ON chats(is_pinned DESC);
CREATE INDEX IF NOT EXISTS idx_chats_sort_order ON chats(sort_order);

-- Update existing chats to have sort_order based on created_at
WITH numbered_chats AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) as rn
    FROM chats
)
UPDATE chats
SET sort_order = numbered_chats.rn
FROM numbered_chats
WHERE chats.id = numbered_chats.id;

