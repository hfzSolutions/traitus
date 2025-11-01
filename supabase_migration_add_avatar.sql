-- Migration: Add avatar_url column to chats table
-- Run this in your Supabase SQL Editor

-- Add avatar_url column to chats table
ALTER TABLE chats ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Create a storage bucket for chat avatars if it doesn't exist
-- Note: Run this in the Supabase Storage UI or via the dashboard
-- Bucket name: chat-avatars
-- Public: true (so avatars can be displayed without authentication)

-- Create a policy to allow users to upload their own avatars
-- This should be set up in Supabase Storage Policies:
-- 1. Allow INSERT for authenticated users on their own files
-- 2. Allow UPDATE for authenticated users on their own files
-- 3. Allow DELETE for authenticated users on their own files
-- 4. Allow SELECT for everyone (public read access)

