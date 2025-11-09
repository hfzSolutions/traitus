# Image Sending Feature

This document describes the image sending feature that allows users to send images in chat messages using OpenRouter's multimodal API.

## Overview

Users can now send images along with text messages in chat conversations. Images are:
- Uploaded to Supabase Storage
- Stored as URLs in the database
- Sent to OpenRouter API using multimodal message format
- Displayed in chat message bubbles

## Features

- 📸 **Image Selection**: Pick images from device gallery
- ☁️ **Cloud Storage**: Images stored in Supabase Storage (`chat-images` bucket)
- 🔗 **URL-based**: Uses URLs (not base64) for efficient storage and retrieval
- 💬 **Multimodal Support**: Images sent to OpenRouter API using content array format
- 🎨 **UI Display**: Images shown in user message bubbles with loading states
- 📱 **Persistent**: Images are saved to database so users can see them again
- 🎯 **Smart Validation**: Image upload button always visible; shows helpful message if model doesn't support images
- 🔢 **Multiple Images**: Support for up to 5 images per message
- 👁️ **Image Previews**: See attached images before sending with ability to remove them

## Setup Instructions

### Step 1: Run Database Migrations

Run these migration SQL files in your Supabase SQL Editor:

**1. Add image_urls to messages table:**
```sql
-- File: supabase_migration_add_image_urls_to_messages.sql
```

**2. Add supports_images to models table:**
```sql
-- File: supabase_migration_add_supports_images_to_models.sql
```

This will:
- Add `image_urls` column (TEXT[]) to the `messages` table
- Create an index for efficient queries on messages with images
- Add `supports_image_input` column (BOOLEAN) to the `models` table
- Enable conditional UI display based on model capabilities
- Note: This is for image input (multimodal), not image generation

### Step 2: Create Supabase Storage Bucket

1. Go to **Supabase Dashboard** → **Storage**
2. Click **"Create a new bucket"**
3. Set the following:
   - **Name**: `chat-images`
   - **Public bucket**: ✅ Yes (checked)
   - **File size limit**: 10 MB (recommended)
   - **Allowed MIME types**: `image/*`

### Step 3: Set Up Storage Policies

After creating the bucket, run these SQL policies in your Supabase SQL Editor:

```sql
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
-- This is required so OpenRouter can download images
CREATE POLICY "Public can view chat images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'chat-images');

-- Policy 3: Allow users to view their own chat images (SELECT)
-- This is redundant but kept for consistency
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
```

**📍 IMPORTANT:** 
1. Create these policies under **"OTHER POLICIES UNDER STORAGE.OBJECTS"**, NOT under the bucket-level policies!
2. **Policy 2 is critical** - it allows OpenRouter (and other external services) to download images without authentication. Without this, you'll get timeout errors.

### Step 4: Configure Model Image Input Support

After running the migration, update your models table to mark which models support image inputs (multimodal):

```sql
-- Mark multimodal models as supporting image inputs
UPDATE models SET supports_image_input = true WHERE slug IN (
  'anthropic/claude-3-opus',
  'anthropic/claude-3-sonnet',
  'anthropic/claude-3-haiku',
  'openai/gpt-4-vision-preview',
  'openai/gpt-4o',
  'openai/gpt-4o-mini',
  'google/gemini-pro-vision',
  'google/gemini-1.5-pro',
  'google/gemini-1.5-flash'
);
```

**Note:** The image upload button is always visible. If a user tries to upload an image with a model that doesn't support image inputs (`supports_image_input = false`), they'll see a helpful toast message suggesting they switch to a multimodal model. This field specifically indicates multimodal input capability, not image generation.

Check [OpenRouter's multimodal documentation](https://openrouter.ai/docs/features/multimodal/images) for the latest list of supported models.

## Implementation Details

### Files Modified

1. **`lib/models/chat_message.dart`**
   - Added `imageUrls` field (List<String>)
   - Updated `toOpenRouterMessage()` to support multimodal format

2. **`lib/services/storage_service.dart`**
   - Added `uploadChatImage()` method
   - Added `deleteChatImage()` method

3. **`lib/services/openrouter_api.dart`**
   - Updated message type from `Map<String, String>` to `Map<String, dynamic>`
   - Supports content arrays for multimodal messages

4. **`lib/providers/chat_provider.dart`**
   - Updated `sendUserMessage()` to accept optional `imageFilePaths`
   - Handles image upload before sending message

5. **`lib/services/database_service.dart`**
   - Updated `createMessage()` to store `image_urls`
   - Updated `_chatMessageFromJson()` to parse `image_urls`

6. **`lib/ui/chat_page.dart`**
   - Added image picker button to input bar (always visible)
   - Updated `_UserBubble` to display images
   - Added image selection callback
   - Validates model support and shows toast if unsupported

7. **`lib/services/models_service.dart`**
   - Added `supportsImageInput` field to `AiModelInfo`
   - Added `getModelBySlug()` method to fetch model info
   - Updated queries to include `supports_image_input` field

8. **`lib/providers/chat_provider.dart`**
   - Added `getCurrentModelSupportsImageInput()` method
   - Checks model capabilities before allowing image uploads

### Message Format

When images are included, messages are sent to OpenRouter in this format:

```json
{
  "role": "user",
  "content": [
    {
      "type": "text",
      "text": "What's in this image?"
    },
    {
      "type": "image_url",
      "image_url": {
        "url": "https://..."
      }
    }
  ]
}
```

## Usage

1. **Attach Image**: Tap the image icon (📷) in the chat input bar
2. **Select Image**: Choose an image from your device gallery
3. **Add More Images (Optional)**: You can attach up to 5 images per message
4. **Add Text (Optional)**: Type a message to accompany the images
5. **Remove Images (Optional)**: Tap the X button on any image preview to remove it
6. **Send**: Tap the send button to upload and send the images with your text

**Note**: Maximum 5 images per message. The image button will show a counter (e.g., "2/5") and disable when the limit is reached.

## Supported Image Formats

- PNG
- JPEG
- WebP
- GIF

## Storage Structure

Images are stored in Supabase Storage with the following path structure:
```
chat-images/
  {userId}/
    {messageId}-{timestamp}.{ext}
```

This ensures:
- Each user's images are isolated
- Each image has a unique filename
- Images can be easily identified and cleaned up if needed

## Error Handling

- Image upload failures are logged but don't block message sending
- Failed image uploads show error indicators in the UI
- Network errors during image loading show broken image icons

## Future Enhancements

Possible future improvements:
- Multiple image selection
- Image compression before upload
- Image preview before sending
- Image editing capabilities
- Camera capture support
- Image deletion from messages

