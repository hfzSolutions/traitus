-- Migration: Restore model selection functionality
-- This migration adds back the models table and model field to chats
-- All models use OpenRouter (db openrouter)

-- ========================================
-- 1. Create models table
-- ========================================
CREATE TABLE IF NOT EXISTS models (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  model_id text NOT NULL UNIQUE, -- OpenRouter model ID (e.g., "openai/gpt-4o-mini")
  provider text NOT NULL DEFAULT 'openrouter', -- Always 'openrouter'
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT models_pkey PRIMARY KEY (id)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_models_active ON models(is_active);
CREATE INDEX IF NOT EXISTS idx_models_provider ON models(provider);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_models_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_models_updated
  BEFORE UPDATE ON models
  FOR EACH ROW
  EXECUTE FUNCTION update_models_updated_at();

-- ========================================
-- 2. Add model field back to chats table
-- ========================================
ALTER TABLE chats ADD COLUMN IF NOT EXISTS model text;

-- Create index for faster queries on model
CREATE INDEX IF NOT EXISTS idx_chats_model ON chats(model);

-- ========================================
-- 3. Insert default models (all using OpenRouter)
-- ========================================
-- Insert popular OpenRouter models
INSERT INTO models (name, model_id, provider, description, is_active) VALUES
  ('GPT-4o Mini', 'openai/gpt-4o-mini', 'openrouter', 'Fast and affordable GPT-4o model', true),
  ('Claude 3.5 Sonnet', 'anthropic/claude-3.5-sonnet', 'openrouter', 'Anthropic''s most capable model', true),
  ('Gemini 2.0 Flash', 'google/gemini-2.0-flash-exp:free', 'openrouter', 'Google''s fast and free model', true),
  ('Minimax M2', 'minimax/minimax-m2:free', 'openrouter', 'Fast and free model', true),
  ('GPT-4o', 'openai/gpt-4o', 'openrouter', 'OpenAI''s flagship model', true),
  ('Claude 3 Opus', 'anthropic/claude-3-opus', 'openrouter', 'Anthropic''s most powerful model', true)
ON CONFLICT (model_id) DO NOTHING;

-- ========================================
-- Notes:
-- - All models use OpenRouter (provider = 'openrouter')
-- - The model_id is the OpenRouter model identifier
-- - Users can select models from the models table
-- - Chats store the selected model_id in the model field
-- - If a chat has no model, it falls back to OPENROUTER_MODEL from env

