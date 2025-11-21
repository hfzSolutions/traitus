# Delete Account Feature

This document explains how to set up and use the delete account feature, which allows users to permanently delete their accounts from the settings page.

## Overview

The delete account feature uses a Supabase Edge Function to securely delete user accounts. This approach:
- Keeps the service role key secure (never exposed to the client)
- Validates user authentication before deletion
- Leverages CASCADE foreign keys for automatic data cleanup
- Provides a safe, controlled way for users to delete their accounts

## Architecture

### Components

1. **Edge Function** (`supabase/functions/delete-account/index.ts`)
   - Validates user authentication
   - Uses service role key to delete the user
   - Returns success/error response

2. **SupabaseService** (`lib/services/supabase_service.dart`)
   - `deleteAccount()` method that calls the edge function
   - Handles authentication token passing

3. **AuthProvider** (`lib/providers/auth_provider.dart`)
   - `deleteAccount()` method that orchestrates the deletion
   - Clears local state and OneSignal external user ID

4. **Settings Page** (`lib/ui/settings_page.dart`)
   - UI for delete account option
   - Two-step confirmation dialog
   - Type-to-confirm final step

## Deployment Steps

### Step 1: Deploy Edge Function

1. Go to Supabase Dashboard → **Edge Functions**
2. Click **Create a new function**
3. Name it: `delete-account`
4. Copy the contents of `supabase/functions/delete-account/index.ts`
5. **Remove the comment markers** (`/*` at the start and `*/` at the end)
6. Paste the code into the function editor
7. Click **Deploy**

### Step 2: Verify Environment Variables

The edge function uses these environment variables (automatically available in Supabase):
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your anon/public key
- `SUPABASE_SERVICE_ROLE_KEY` - Your service role key (automatically available)

These are automatically set by Supabase, so no manual configuration is needed.

### Step 3: Test the Function

1. Go to Supabase Dashboard → **Edge Functions** → `delete-account`
2. Click **Invoke function**
3. You should see an error (expected - needs authentication)
4. The function is ready when it returns a 401 error (missing auth)

## How It Works

### User Flow

1. User navigates to **Settings** → **Account** section
2. User taps **Delete Account**
3. First confirmation dialog appears with warning about data deletion
4. If confirmed, second dialog appears requiring user to type "DELETE"
5. If confirmed, loading indicator shows while deletion is in progress
6. On success, user is logged out and redirected to auth screen
7. On error, error message is shown

### Technical Flow

1. **Client** (`settings_page.dart`)
   - Shows confirmation dialogs
   - Calls `authProvider.deleteAccount()`

2. **AuthProvider** (`auth_provider.dart`)
   - Calls `supabaseService.deleteAccount()`
   - Clears local state on success

3. **SupabaseService** (`supabase_service.dart`)
   - Gets current session token
   - Calls edge function with authentication header

4. **Edge Function** (`delete-account/index.ts`)
   - Validates user token
   - Extracts user ID
   - Uses service role key to delete user via `admin.deleteUser()`
   - CASCADE foreign keys automatically delete:
     - `user_profiles`
     - `user_entitlements`
     - `notes` (and `note_sections`)
     - `chats` (and `messages`)
   - Storage cleanup trigger deletes:
     - User avatars
     - Chat avatars
     - Chat images

## Security

### Authentication
- Edge function validates the user's JWT token
- Only authenticated users can delete their own account
- Service role key is never exposed to the client

### Authorization
- Users can only delete their own account
- The edge function verifies the token matches the user being deleted

### Data Cleanup
- CASCADE foreign keys ensure all related data is deleted
- Storage cleanup trigger removes all user files
- No orphaned data remains

## UI Features

### Confirmation Dialogs

**First Dialog:**
- Warning about permanent deletion
- Lists what will be deleted
- Cancel/Continue buttons

**Second Dialog:**
- Type-to-confirm pattern
- User must type "DELETE" exactly
- Prevents accidental deletion
- Disabled button until text matches

### Loading State
- Shows circular progress indicator during deletion
- Non-dismissible (prevents user from navigating away)

### Error Handling
- Shows error dialog if deletion fails
- User remains logged in on error
- Error message is user-friendly

## Testing

### Manual Testing

1. **Test Successful Deletion:**
   - Log in as a test user
   - Go to Settings → Delete Account
   - Complete both confirmation dialogs
   - Verify account is deleted and user is logged out

2. **Test Cancellation:**
   - Start deletion process
   - Cancel at first dialog
   - Verify user remains logged in

3. **Test Type-to-Confirm:**
   - Start deletion process
   - Confirm first dialog
   - Try typing wrong text
   - Verify button is disabled
   - Type "DELETE" correctly
   - Verify button is enabled

4. **Test Error Handling:**
   - Temporarily break the edge function
   - Try to delete account
   - Verify error message appears
   - Verify user remains logged in

### Edge Function Testing

Test the edge function directly:

```bash
# Get your access token from the app (logged in user)
# Replace YOUR_PROJECT_REF and YOUR_ACCESS_TOKEN

curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/delete-account \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json"
```

## Troubleshooting

### Error: "Missing authorization header"
- **Cause**: Edge function not receiving auth token
- **Fix**: Check that `SupabaseService.deleteAccount()` is passing the token correctly

### Error: "Invalid or expired token"
- **Cause**: User's session has expired
- **Fix**: User should log out and log back in

### Error: "Failed to delete user account"
- **Cause**: Database error or missing CASCADE foreign keys
- **Fix**: 
  1. Check edge function logs in Supabase Dashboard
  2. Verify CASCADE foreign keys are set (run `supabase_migration_fix_user_deletion_complete.sql`)
  3. Check for any database constraints blocking deletion

### Account deleted but data remains
- **Cause**: CASCADE foreign keys not set properly
- **Fix**: Run `supabase_migration_fix_user_deletion_complete.sql` migration

### UI not showing delete option
- **Cause**: Code not deployed or build issue
- **Fix**: 
  1. Verify `settings_page.dart` has the delete account ListTile
  2. Rebuild the app
  3. Check for compilation errors

## Related Files

- `supabase/functions/delete-account/index.ts` - Edge function code
- `lib/services/supabase_service.dart` - Service method to call edge function
- `lib/providers/auth_provider.dart` - Provider method for account deletion
- `lib/ui/settings_page.dart` - UI for delete account feature
- `supabase_migration_fix_user_deletion_complete.sql` - Database migration for CASCADE foreign keys
- `USER_DELETION_FIX.md` - Documentation for fixing user deletion errors

## Notes

- The edge function code is commented out in the file to avoid local IDE errors (Deno not installed)
- Uncomment the code before deploying to Supabase
- The function uses `admin.deleteUser()` which requires service role key
- All data deletion happens automatically via CASCADE foreign keys
- Storage cleanup happens via database triggers
- The feature requires the user deletion fix migration to be applied first

## Last Updated

November 21, 2025

