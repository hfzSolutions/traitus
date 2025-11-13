-- Migration: Add app_config table for storing default model configurations
-- This allows models to be configured in the database instead of environment variables

-- ========================================
-- 1. Create app_config table
-- ========================================
CREATE TABLE IF NOT EXISTS app_config (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  value text NOT NULL,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT app_config_pkey PRIMARY KEY (id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_app_config_key ON app_config(key);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_app_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_app_config_updated
  BEFORE UPDATE ON app_config
  FOR EACH ROW
  EXECUTE FUNCTION update_app_config_updated_at();

-- ========================================
-- 2. Insert default model configurations
-- ========================================
-- These will be used as fallbacks if not set, or can be updated via admin
INSERT INTO app_config (key, value, description) VALUES
  ('default_model', 'minimax/minimax-m2:free', 'Default model for all chats (OpenRouter model ID)'),
  ('onboarding_model', 'minimax/minimax-m2:free', 'Model used for onboarding/assistant finding (OpenRouter model ID)'),
  ('quick_reply_model', 'minimax/minimax-m2:free', 'Model used for quick reply generation (OpenRouter model ID)')
ON CONFLICT (key) DO NOTHING;

-- ========================================
-- Notes:
-- - All models use OpenRouter (provider = 'openrouter')
-- - The value should be a valid OpenRouter model ID (e.g., "openai/gpt-4o-mini")
-- - If a config value is not set, the app will fallback to environment variables
-- - Admins can update these values via database or admin panel
-- - The app will check database first, then fallback to env vars for backward compatibility

