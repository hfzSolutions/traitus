-- Migration: Add App Version Control
-- Description: Allows remote control of app version requirements and force updates
-- Date: 2025-11-05

-- Create app_version_control table
CREATE TABLE IF NOT EXISTS public.app_version_control (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web', 'all')),
    
    -- Version information
    minimum_version TEXT NOT NULL, -- e.g., "1.0.0"
    minimum_build_number INTEGER NOT NULL, -- e.g., 1
    latest_version TEXT NOT NULL, -- e.g., "1.2.0"
    latest_build_number INTEGER NOT NULL, -- e.g., 15
    
    -- Control flags
    force_update BOOLEAN DEFAULT false, -- If true, users below minimum_version cannot use the app
    show_update_prompt BOOLEAN DEFAULT true, -- Show optional update prompt if not on latest
    
    -- Update information
    update_message TEXT, -- Custom message to show users
    update_title TEXT DEFAULT 'Update Available',
    
    -- Store links
    ios_app_store_url TEXT,
    android_play_store_url TEXT,
    web_app_url TEXT,
    
    -- Maintenance mode
    maintenance_mode BOOLEAN DEFAULT false,
    maintenance_message TEXT DEFAULT 'App is currently under maintenance. Please check back later.',
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure one record per platform
    CONSTRAINT unique_platform UNIQUE (platform)
);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_app_version_control_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER app_version_control_updated_at
    BEFORE UPDATE ON public.app_version_control
    FOR EACH ROW
    EXECUTE FUNCTION update_app_version_control_updated_at();

-- Insert default version control records
INSERT INTO public.app_version_control (
    platform,
    minimum_version,
    minimum_build_number,
    latest_version,
    latest_build_number,
    force_update,
    show_update_prompt,
    update_message,
    ios_app_store_url,
    android_play_store_url,
    web_app_url
) VALUES 
(
    'ios',
    '1.0.0',
    1,
    '1.0.0',
    1,
    false,
    false,
    'A new version is available with bug fixes and improvements!',
    'https://apps.apple.com/app/your-app-id',
    NULL,
    NULL
),
(
    'android',
    '1.0.0',
    1,
    '1.0.0',
    1,
    false,
    false,
    'A new version is available with bug fixes and improvements!',
    NULL,
    'https://play.google.com/store/apps/details?id=your.package.name',
    NULL
),
(
    'all',
    '1.0.0',
    1,
    '1.0.0',
    1,
    false,
    false,
    'A new version is available with bug fixes and improvements!',
    'https://apps.apple.com/app/your-app-id',
    'https://play.google.com/store/apps/details?id=your.package.name',
    'https://your-web-app.com'
)
ON CONFLICT (platform) DO NOTHING;

-- Enable RLS
ALTER TABLE public.app_version_control ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read version control (needed for non-authenticated checks)
CREATE POLICY "Anyone can read app version control"
    ON public.app_version_control
    FOR SELECT
    USING (true);

-- Only service role can modify version control
-- (You'll manage this from Supabase dashboard or backend)

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_app_version_control_platform 
    ON public.app_version_control(platform);

-- Add comments for documentation
COMMENT ON TABLE public.app_version_control IS 'Controls app version requirements and force update behavior';
COMMENT ON COLUMN public.app_version_control.minimum_version IS 'Minimum version required to use the app (semantic version string)';
COMMENT ON COLUMN public.app_version_control.minimum_build_number IS 'Minimum build number required to use the app';
COMMENT ON COLUMN public.app_version_control.latest_version IS 'Latest available version in stores';
COMMENT ON COLUMN public.app_version_control.force_update IS 'If true, users below minimum_version must update';
COMMENT ON COLUMN public.app_version_control.show_update_prompt IS 'Show optional update prompt for users not on latest';
COMMENT ON COLUMN public.app_version_control.maintenance_mode IS 'If true, app shows maintenance screen to all users';

