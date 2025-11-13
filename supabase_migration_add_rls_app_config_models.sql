-- Migration: Add Row Level Security (RLS) policies for app_config and models tables
-- This ensures proper access control for configuration and model data

-- ========================================
-- 1. Enable RLS on app_config table
-- ========================================
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read app_config (they need to know which models to use)
CREATE POLICY "Allow authenticated users to read app_config"
  ON app_config
  FOR SELECT
  TO authenticated
  USING (true);

-- Only allow service role to insert/update/delete app_config
-- This prevents regular users from modifying configuration
-- To modify app_config, use the Supabase dashboard or service role API key
-- If you need admin users to manage this, you can add a policy like:
-- USING (auth.jwt() ->> 'user_role' = 'admin')
-- Note: No INSERT/UPDATE/DELETE policies means only service role can modify

-- ========================================
-- 2. Enable RLS on models table
-- ========================================
ALTER TABLE models ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read models (they need to see available models)
CREATE POLICY "Allow authenticated users to read models"
  ON models
  FOR SELECT
  TO authenticated
  USING (true);

-- Only allow service role to insert/update/delete models
-- This prevents regular users from modifying the models list
-- To modify models, use the Supabase dashboard or service role API key
-- If you need admin users to manage this, you can add a policy like:
-- USING (auth.jwt() ->> 'user_role' = 'admin')
-- Note: No INSERT/UPDATE/DELETE policies means only service role can modify

-- ========================================
-- Notes:
-- - All authenticated users can READ app_config and models (they need this data)
-- - Only service role can INSERT/UPDATE/DELETE (no policies = service role only)
-- - To allow admin users to manage, add policies with admin role check:
--   CREATE POLICY "Allow admins to manage app_config"
--     ON app_config FOR ALL TO authenticated
--     USING (auth.jwt() ->> 'user_role' = 'admin')
--     WITH CHECK (auth.jwt() ->> 'user_role' = 'admin');
-- - To modify these tables, use Supabase dashboard with service role or backend API

