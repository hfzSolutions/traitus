-- Storage Policies for chat-images bucket
-- Run this SQL in your Supabase SQL Editor
-- 
-- IMPORTANT: These policies must be created under "OTHER POLICIES UNDER STORAGE.OBJECTS"
-- NOT under bucket-level policies!

-- Policy 1: Allow users to upload their own chat images (INSERT)
CREATE POLICY "Users can upload their own chat images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-images' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Allow PUBLIC access to view chat images (SELECT)
-- This is REQUIRED so OpenRouter can download images without authentication
-- Without this policy, OpenRouter will timeout when trying to download images
CREATE POLICY "Public can view chat images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'chat-images');

-- Policy 3: Allow users to view their own chat images (SELECT)
-- This is redundant but kept for consistency and explicit user access
CREATE POLICY "Users can view their own chat images"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'chat-images' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 4: Allow users to delete their own chat images (DELETE)
CREATE POLICY "Users can delete their own chat images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'chat-images' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

