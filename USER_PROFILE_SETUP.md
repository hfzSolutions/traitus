# User Profile Setup Guide

This guide explains how to set up user profile functionality in your Traitus AI app, including profile picture uploads.

## Features

- ✅ User profile pictures
- ✅ Display name support
- ✅ Automatic profile creation on signup
- ✅ Profile picture upload and update
- ✅ Secure storage with Supabase Storage

## Supabase Setup

### 1. Run Database Migration

Run the SQL migration in your Supabase SQL Editor:

```sql
-- File: supabase_migration_add_user_profiles.sql
```

This will:
- Create the `user_profiles` table
- Set up Row Level Security (RLS) policies
- Create a trigger to automatically create profiles on user signup
- Add necessary indexes

### 2. Create Storage Bucket for User Avatars

1. Go to Supabase Dashboard → Storage
2. Click "Create a new bucket"
3. Set the following:
   - **Name**: `user-avatars`
   - **Public bucket**: ✅ Yes (checked)
   - **File size limit**: 5 MB (recommended)
   - **Allowed MIME types**: `image/*`

### 3. Set Up Storage Policies

After creating the bucket, run these SQL policies in your Supabase SQL Editor:

```sql
-- ========================================
-- STORAGE POLICIES FOR USER-AVATARS BUCKET
-- ========================================

-- Policy 1: Allow users to upload their own avatars (INSERT)
CREATE POLICY "Users can upload their own avatars"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'user-avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Allow users to update their own avatars (UPDATE)
CREATE POLICY "Users can update their own avatars"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'user-avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'user-avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 3: Allow users to delete their own avatars (DELETE)
CREATE POLICY "Users can delete their own avatars"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'user-avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 4: Allow public read access to all avatars (SELECT)
CREATE POLICY "Public avatar access"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'user-avatars');
```

**What each policy does:**
- **INSERT**: Users can upload avatars to their own folder (`{user_id}/profile.jpg`)
- **UPDATE**: Users can replace/update their existing avatar
- **DELETE**: Users can delete their own avatar
- **SELECT**: Anyone can view avatars (required for displaying in the app)

**Verify the policies:**
- Go to Storage → `user-avatars` bucket → Policies tab
- You should see all 4 policies listed

## App Usage

### Uploading Profile Picture

1. Open the app and navigate to the **Profile** tab (bottom navigation)
2. Tap on your profile picture (or the default avatar icon)
3. Select an image from your gallery
4. The image will be automatically uploaded and your profile will be updated

### Technical Details

#### User Profile Model
```dart
class UserProfile {
  final String id;              // User ID from auth.users
  final String? avatarUrl;      // Public URL to profile picture
  final String? displayName;    // User's display name
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### Storage Structure
User avatars are stored in the following format:
```
user-avatars/
  ├── {user_id}/
  │   └── profile.{ext}  (jpg, png, etc.)
```

#### Automatic Profile Creation
When a user signs up, a profile is automatically created via the `create_user_profile()` trigger function. The display name is set to:
1. The value from `raw_user_meta_data->>'display_name'` if available
2. Otherwise, the part before @ in their email address

## Image Optimization

Profile pictures are automatically optimized during upload:
- **Max dimensions**: 512x512 pixels
- **Format**: Maintains original format (JPEG, PNG, etc.)
- **Quality**: 85% (for JPEGs)
- **Cache control**: 1 hour (3600 seconds)
- **Upsert**: Yes (replaces existing image)

## Security

- ✅ Row Level Security (RLS) enabled on `user_profiles` table
- ✅ Users can only view, create, and update their own profile
- ✅ Storage policies ensure users can only upload/modify their own avatars
- ✅ Public read access for avatars (required for displaying in UI)
- ✅ Profile pictures are stored with cache-busting timestamps

## Troubleshooting

### Profile picture not appearing
1. Check that the `user-avatars` bucket is set to **public**
2. Verify storage policies are correctly set up
3. Check browser console for CORS or network errors
4. Try clearing the app cache and re-uploading

### "User not authenticated" error
- Ensure the user is properly signed in
- Check that the session is valid
- Try signing out and signing back in

### Upload fails
1. Check image file size (should be under 5 MB)
2. Verify the image is a valid format (JPEG, PNG, GIF, WebP)
3. Check Supabase storage quota
4. Review Supabase logs for detailed error messages

## Database Schema

### user_profiles Table
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key, references auth.users(id) |
| avatar_url | TEXT | Public URL to profile picture |
| display_name | TEXT | User's display name |
| created_at | TIMESTAMPTZ | Profile creation timestamp |
| updated_at | TIMESTAMPTZ | Last update timestamp |

### Indexes
- `idx_user_profiles_id` on `id` column for faster queries

## Future Enhancements

Potential features to add:
- [ ] Edit display name in-app
- [ ] Remove profile picture option
- [ ] Image cropping before upload
- [ ] Support for taking photos with camera
- [ ] Profile bio/description field
- [ ] Account creation date display
- [ ] Usage statistics

