# Signup Error Fix Instructions

## Problem
Users are getting this error when signing up with email/password:
```
AuthRetryableFetchException
{"code": "unexpected_failure", "message": "Database error saving new user", statusCode: 500}
```

## Root Cause
The database trigger function `create_user_profile()` is incomplete and failing to create user profiles when new users sign up. Your current function only inserts `id` and `display_name`, but the table requires additional fields like `onboarding_completed` and `preferences`.

## Solution

### Step 1: Fix the Database Trigger (REQUIRED)

1. Open your **Supabase Dashboard**
2. Go to **SQL Editor**
3. Copy and paste the entire content of `supabase_fix_signup_trigger.sql`
4. Click **Run**

This will:
- ✅ Replace the broken trigger function with a robust one
- ✅ Add all required fields (onboarding_completed, preferences, created_at, updated_at)
- ✅ Add error handling so signups don't crash
- ✅ Add conflict handling (ON CONFLICT DO NOTHING)
- ✅ Set proper security (SECURITY DEFINER, search_path)
- ✅ Backfill any existing users who signed up while trigger was broken

### Step 2: Test the Fix

After running the SQL, test signup:

1. Try signing up with a new email address
2. You should see:
   - No error messages
   - User created successfully
   - Redirected to auth/login page
3. Sign in with the new account
4. You should be directed to onboarding

### Step 3: Verify the Fix

Check in Supabase:

1. Go to **Table Editor** → **user_profiles**
2. You should see the new user's profile with:
   - ✅ `id` (matches auth.users id)
   - ✅ `display_name` (email prefix)
   - ✅ `onboarding_completed` = false
   - ✅ `preferences` = []
   - ✅ `created_at` and `updated_at` timestamps

## What Changed in the Code

### 1. Database Trigger Fix (`supabase_fix_signup_trigger.sql`)
- Complete rewrite of `create_user_profile()` function
- Adds all required fields
- Error handling and conflict resolution

### 2. Flutter App Improvements

#### `database_service.dart`
- Added `ensureUserProfileExists()` - fallback mechanism if trigger fails

#### `auth_provider.dart`
- Updated `signUp()` to ensure profile exists before signing out
- Updated `_loadUserProfile()` to auto-create missing profiles
- Added `resendVerificationEmail()` method

#### `supabase_service.dart`
- Added `resendVerificationEmail()` method

#### `signup_page.dart` ✨ NEW UX
- ✅ Shows beautiful modal bottom sheet after successful signup
- ✅ Circular icon container with email icon
- ✅ Displays user's email address in highlighted container
- ✅ Orange info box for spam folder reminder
- ✅ Includes "Resend Email" button if user didn't receive it
- ✅ Side-by-side buttons for better mobile UX

#### `auth_page.dart` 
- Removed outdated success message
- Clean navigation flow

## How the Fix Works

### Before (Broken)
```sql
BEGIN
    INSERT INTO user_profiles (id, display_name)
    VALUES (NEW.id, COALESCE(...));
    RETURN NEW;
END;
```
❌ Missing required fields  
❌ No error handling  
❌ Fails entire signup on error

### After (Fixed)
```sql
BEGIN
    INSERT INTO public.user_profiles (
        id, 
        display_name,
        onboarding_completed,
        preferences,
        created_at,
        updated_at
    )
    VALUES (NEW.id, COALESCE(...), false, ARRAY[]::text[], NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error: %', SQLERRM;
        RETURN NEW;
END;
```
✅ All required fields  
✅ Error handling  
✅ Doesn't fail signup on error  
✅ Conflict handling  
✅ Plus Flutter fallback

## Testing Checklist

- [ ] Run `supabase_fix_signup_trigger.sql` in Supabase SQL Editor
- [ ] Try signing up with a new email
- [ ] Verify no error message appears
- [ ] Check user_profiles table for new entry
- [ ] Sign in with new account
- [ ] Verify onboarding flow works
- [ ] Test Google Sign-In (should also work)

## If Problems Persist

1. **Check Supabase logs**: Dashboard → Logs → look for trigger errors
2. **Verify RLS policies**: Make sure `user_profiles` RLS allows INSERT for authenticated users
3. **Check column defaults**: Verify all columns have proper DEFAULT values
4. **Test manually**: Try inserting a profile directly in SQL Editor

## Support

If you still have issues after running the SQL fix, check:
- Supabase logs for detailed error messages
- Row Level Security policies on `user_profiles` table
- Database permissions for the trigger function

