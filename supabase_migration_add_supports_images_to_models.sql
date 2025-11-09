-- Migration: Add supports_image_input field to models table
-- Run this SQL in your Supabase SQL Editor if you already have an existing database

-- Add supports_image_input column to models table
-- This indicates whether the model can accept image inputs (multimodal input)
-- Note: This is different from image generation capability
ALTER TABLE models ADD COLUMN IF NOT EXISTS supports_image_input BOOLEAN NOT NULL DEFAULT false;

-- Optional: Add an index if you plan to query by image input support frequently
CREATE INDEX IF NOT EXISTS idx_models_supports_image_input ON models(supports_image_input) WHERE supports_image_input = true;

-- Example: Update known multimodal models to support image inputs
-- Uncomment and modify these based on your actual model slugs
-- UPDATE models SET supports_image_input = true WHERE slug IN (
--   'anthropic/claude-3-opus',
--   'anthropic/claude-3-sonnet',
--   'anthropic/claude-3-haiku',
--   'openai/gpt-4-vision-preview',
--   'openai/gpt-4o',
--   'openai/gpt-4o-mini',
--   'google/gemini-pro-vision',
--   'google/gemini-1.5-pro',
--   'google/gemini-1.5-flash'
-- );

