-- =====================================================
-- FIX RLS POLICY FOR APP_CONFIG TABLE
-- =====================================================
-- This script checks and fixes the RLS policy for app_config table
-- Run this in Supabase SQL Editor

-- Step 1: Check if RLS is enabled (should return true)
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'app_config';

-- Step 2: List all existing policies on app_config
SELECT * 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'app_config';

-- Step 3: Drop existing policy if it has issues (uncomment if needed)
-- DROP POLICY IF EXISTS "Allow authenticated users to read app_config" ON app_config;

-- Step 4: Create the correct policy
-- This allows ALL authenticated users to read app_config
DROP POLICY IF EXISTS "Allow authenticated users to read app_config" ON app_config;

CREATE POLICY "Allow authenticated users to read app_config"
  ON app_config
  FOR SELECT
  TO authenticated
  USING (true);

-- Step 5: Verify the policy was created
SELECT * 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'app_config';

-- Step 6: Test the query as an authenticated user
-- This should return your config data
SELECT key, value FROM app_config;

-- =====================================================
-- ALSO FIX MODELS TABLE (same issue)
-- =====================================================

DROP POLICY IF EXISTS "Allow authenticated users to read models" ON models;

CREATE POLICY "Allow authenticated users to read models"
  ON models
  FOR SELECT
  TO authenticated
  USING (true);

-- Verify models policy
SELECT * 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'models';

-- Test models query
SELECT * FROM models WHERE is_active = true;

-- =====================================================
-- EXPECTED RESULTS:
-- =====================================================
-- After running this, you should see:
-- 1. app_config has RLS enabled (rowsecurity = true)
-- 2. Policy "Allow authenticated users to read app_config" exists
-- 3. SELECT query returns your 3 config rows:
--    - default_model: google/gemini-2.5-flash
--    - onboarding_model: google/gemini-2.5-flash
--    - quick_reply_model: google/gemini-2.5-flash



