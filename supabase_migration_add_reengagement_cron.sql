-- Migration: Add pg_cron job for re-engagement notifications
-- This creates a scheduled job to run the re-engagement edge function daily
--
-- IMPORTANT: For hosted Supabase projects, use the Dashboard method (see below)
-- This SQL file is provided as an alternative if you prefer SQL

-- ========================================
-- OPTION 1: Using Supabase Dashboard (RECOMMENDED)
-- ========================================
-- 1. Go to Supabase Dashboard → Database → Cron Jobs
-- 2. Click "New Cron Job"
-- 3. Configure:
--    - Name: send-reengagement-notifications
--    - Schedule: 0 10 * * * (daily at 10:00 AM UTC)
--    - Command: Copy the SQL from OPTION 2 below (replace placeholders)
-- 4. Click "Create"

-- ========================================
-- OPTION 2: Using SQL (Alternative)
-- ========================================
-- Run this SQL in Supabase Dashboard → SQL Editor
-- Replace YOUR_PROJECT_REF and YOUR_ANON_KEY with your actual values

/*
SELECT cron.schedule(
  'send-reengagement-notifications',  -- Job name
  '0 10 * * *',                        -- Run daily at 10:00 AM UTC (cron format)
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-reengagement-notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_ANON_KEY'
      ),
      body := '{}'::jsonb
    ) AS request_id;
  $$
);
*/

-- ========================================
-- How to Find Your Values
-- ========================================
-- YOUR_PROJECT_REF:
--   - Found in your Supabase project URL: https://YOUR_PROJECT_REF.supabase.co
--   - Or go to Dashboard → Settings → General → Reference ID
--
-- YOUR_ANON_KEY:
--   - Go to Dashboard → Settings → API
--   - Copy the "anon public" key (not the service_role key)

-- ========================================
-- Testing
-- ========================================
-- To manually test the function:
-- curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-reengagement-notifications \
--   -H "Authorization: Bearer YOUR_ANON_KEY" \
--   -H "Content-Type: application/json" \
--   -d '{}'

-- ========================================
-- Management
-- ========================================
-- View cron job logs:
-- SELECT * FROM cron.job_run_details 
-- WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'send-reengagement-notifications');

-- Unschedule the job:
-- SELECT cron.unschedule('send-reengagement-notifications');

-- See all scheduled jobs:
-- SELECT * FROM cron.job;

