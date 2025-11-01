# AI Avatar Feature

This document describes the custom AI avatar feature that allows users to set personalized images for their AI chat assistants.

## Overview

Users can now upload custom avatar images for each AI chat. These avatars will be displayed in:
- Chat list page (in the chat item)
- Chat page header (AppBar with avatar and name)
- Edit chat modals (both locations)

## Features

- 📸 **Image Selection**: Pick images from device gallery
- ☁️ **Cloud Storage**: Images are stored in Supabase Storage
- 🔄 **Update Support**: Replace existing avatars with new ones
- 🗑️ **Automatic Cleanup**: Old avatars are deleted when replaced
- 🎨 **Fallback UI**: Default robot icon shown when no avatar is set
- ⚡ **Optimized**: Images are automatically resized to 512x512 pixels at 85% quality

## Setup Instructions

### 1. Database Migration

Run the migration SQL to add the `avatar_url` column to the chats table:

```sql
-- Run this in your Supabase SQL Editor
ALTER TABLE chats ADD COLUMN IF NOT EXISTS avatar_url TEXT;
```

Or use the provided migration file:
```bash
# Apply: supabase_migration_add_avatar.sql
```

### 2. Supabase Storage Configuration

You need to create a storage bucket for chat avatars:

1. **Go to Supabase Dashboard** → Storage
2. **Create a new bucket** named: `chat-avatars`
3. **Set it as Public** (so avatars can be displayed without authentication)

#### Storage Policies

You need to create 4 policies for the `storage.objects` table. These policies control who can upload, update, delete, and view avatar images.

**📍 IMPORTANT:** Create these policies under **"OTHER POLICIES UNDER STORAGE.OBJECTS"**, NOT under the bucket-level policies!

##### Option 1: Quick Setup Using SQL Editor (Recommended ⚡)

1. Go to **SQL Editor** in your Supabase Dashboard
2. Click **"New query"**
3. Copy and paste this entire SQL block:

```sql
-- All 4 policies for chat-avatars bucket
-- Copy this entire block and click RUN

-- Policy 1: Let users upload avatars
CREATE POLICY "Users can upload avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Let users update their avatars
CREATE POLICY "Users can update their avatars"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'chat-avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'chat-avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 3: Let users delete their avatars
CREATE POLICY "Users can delete their avatars"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'chat-avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 4: Let everyone view avatars (public access)
CREATE POLICY "Avatars are publicly accessible"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chat-avatars');
```

4. Click **"Run"**
5. Done! ✅

##### Option 2: Manual Setup Using Dashboard UI

If you prefer to create policies manually:

1. Go to **Storage** → **Policies** in Supabase Dashboard
2. Scroll down to the **"Schema"** section
3. Find **"OTHER POLICIES UNDER STORAGE.OBJECTS"**
4. Click **"New policy"** on that row (NOT on the bucket row!)

For each of the 4 policies below:

**Policy 1: INSERT (Upload)**
- Policy Name: `Users can upload avatars`
- Allowed operation: **INSERT**
- Target roles: `authenticated`
- WITH CHECK expression:
  ```sql
  bucket_id = 'chat-avatars' AND (storage.foldername(name))[1] = auth.uid()::text
  ```

**Policy 2: UPDATE (Replace)**
- Policy Name: `Users can update their avatars`
- Allowed operation: **UPDATE**
- Target roles: `authenticated`
- USING expression:
  ```sql
  bucket_id = 'chat-avatars' AND (storage.foldername(name))[1] = auth.uid()::text
  ```
- WITH CHECK expression:
  ```sql
  bucket_id = 'chat-avatars' AND (storage.foldername(name))[1] = auth.uid()::text
  ```

**Policy 3: DELETE (Remove)**
- Policy Name: `Users can delete their avatars`
- Allowed operation: **DELETE**
- Target roles: `authenticated`
- USING expression:
  ```sql
  bucket_id = 'chat-avatars' AND (storage.foldername(name))[1] = auth.uid()::text
  ```

**Policy 4: SELECT (View)**
- Policy Name: `Avatars are publicly accessible`
- Allowed operation: **SELECT**
- Target roles: `public`
- USING expression:
  ```sql
  bucket_id = 'chat-avatars'
  ```

##### Verify Policies Are Working

After creating the policies:
1. Go back to **Storage** → **Policies**
2. Under **"OTHER POLICIES UNDER STORAGE.OBJECTS"** you should see 4 policies
3. The bucket-level section can remain empty (that's normal!)

**What these policies do:**
- 🔒 Users can only upload/update/delete files in their own user ID folder
- 👁️ Everyone can view the images (needed to display avatars in the app)
- ✅ Security: Each user's avatars are isolated by their user ID

### 3. Mobile Platform Configuration

#### iOS Configuration

Add the following to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to set AI chat avatars</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take photos for AI chat avatars</string>
```

#### Android Configuration

Add to `android/app/src/main/AndroidManifest.xml` (inside `<manifest>` tag):

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

For Android 13+ (API 33+), also add:
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

## Usage

### Creating a Chat with Avatar

1. Tap the "New AI Chat" button
2. Tap on the avatar circle at the top
3. Select an image from your gallery
4. Fill in the AI name and system prompt
5. Tap "Create AI"

The image will be automatically:
- Resized to 512x512 pixels
- Compressed to 85% quality
- Uploaded to Supabase Storage
- Linked to the chat

### Editing Chat Avatar

1. Long-press on a chat in the list (or tap the menu in chat page)
2. Select "Edit Chat Settings"
3. Tap on the avatar to change it
4. Select a new image
5. Tap "Save Changes"

The old avatar will be automatically deleted and replaced with the new one.

### Avatar Display

- **With Custom Avatar**: Shows the uploaded image in a circular frame
- **Without Custom Avatar**: Shows default robot icon
- **Loading Error**: Fallback to default robot icon

## File Structure

```
lib/
├── models/
│   └── ai_chat.dart                 # Updated with avatarUrl field
├── services/
│   └── storage_service.dart         # New service for avatar uploads
└── ui/
    └── chat_list_page.dart          # Updated with avatar picker UI
```

## Technical Details

### Storage Service (`storage_service.dart`)

The `StorageService` class provides methods for:
- `uploadAvatar()`: Upload a new avatar image
- `deleteAvatar()`: Delete an existing avatar
- `updateAvatar()`: Replace old avatar with new one

### File Naming Convention

Avatars are stored with the following path structure:
```
chat-avatars/
  └── {userId}/
      └── {chatId}.{ext}
```

This ensures:
- Each user's avatars are in their own folder
- Easy to find and manage
- No naming conflicts between users
- Simple cleanup when deleting chats

### Image Optimization

Images are automatically optimized:
- **Max dimensions**: 512x512 pixels
- **Quality**: 85%
- **Format**: Original format preserved (jpg, png, etc.)

This keeps file sizes small while maintaining good quality.

## Error Handling

The feature includes comprehensive error handling:
- Failed uploads show error messages
- Network errors are caught and displayed
- Invalid image formats fall back to default icon
- Storage errors don't crash the app

## Future Enhancements

Potential improvements for the avatar feature:
- [ ] Show avatar in chat page header
- [ ] Support taking photos with camera
- [ ] Add avatar cropping functionality
- [ ] Support GIF avatars
- [ ] Add avatar gallery/presets
- [ ] Share avatars between chats

## Troubleshooting

### Avatar not displaying
- Check if the Supabase bucket is public
- Verify the storage policies are correctly set up
- Check network connection
- Look for console errors about CORS or permissions

### Upload failing
- Verify the bucket name is `chat-avatars`
- Check storage policies allow INSERT for authenticated users
- Ensure user is authenticated
- Check file size isn't too large

### Permissions errors on mobile
- Make sure Info.plist (iOS) or AndroidManifest.xml (Android) has correct permissions
- Restart app after adding permissions
- Check device settings allow photo access

## Dependencies

- `image_picker: ^1.0.7` - For selecting images from gallery
- `supabase_flutter: ^2.7.0` - For storage and database operations

