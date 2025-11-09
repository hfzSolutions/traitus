-- Migration: Add image_urls field to messages table for multimodal support
-- Run this SQL in your Supabase SQL Editor if you already have an existing database

-- Add image_urls column to messages table (stored as JSONB array)
ALTER TABLE messages ADD COLUMN IF NOT EXISTS image_urls TEXT[];

-- Optional: Add an index if you plan to query messages with images frequently
CREATE INDEX IF NOT EXISTS idx_messages_has_images ON messages USING GIN (image_urls) WHERE image_urls IS NOT NULL AND array_length(image_urls, 1) > 0;

