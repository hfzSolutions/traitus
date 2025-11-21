# User Deletion Fix Documentation

## Problem

When attempting to delete a user from the Supabase dashboard, the following error occurs:

```
ERROR: relation "chats" does not exist (SQLSTATE 42P01)
500: Database error deleting user
```

## Root Cause

The issue was caused by two problems:

1. **Unqualified table names in `cleanup_user_data` function**: The function was using `DELETE FROM chats` instead of `DELETE FROM public.chats`, causing PostgreSQL to look for the table in the wrong schema during user deletion.

2. **Missing CASCADE on foreign keys**: The foreign key constraints in the database schema were missing `ON DELETE CASCADE`, which means PostgreSQL would prevent user deletion if there were related rows in other tables.

## Solution

Two migration files were created to fix this issue:

### 1. Quick Fix (Immediate Solution)

**File**: `supabase_quick_fix_cleanup_user_data.sql`

This migration fixes the immediate error by:
- Updating the `cleanup_user_data` function to use qualified table names (`public.chats`, `public.notes`)
- Adding proper error handling
- Ensuring the trigger is properly configured

**When to use**: Run this first to fix the immediate deletion error.

### 2. Complete Fix (Recommended)

**File**: `supabase_migration_fix_user_deletion_complete.sql`

This comprehensive migration:
- Fixes the `cleanup_user_data` function with qualified table names
- Adds `ON DELETE CASCADE` to all foreign keys that reference `auth.users`:
  - `user_profiles.id` → `auth.users(id)`
  - `user_entitlements.user_id` → `auth.users(id)`
  - `notes.user_id` → `auth.users(id)`
  - `chats.user_id` → `auth.users(id)`
  - `messages.user_id` → `auth.users(id)`
- Adds `ON DELETE CASCADE` to `note_sections.note_id` → `notes(id)`
- Adds `ON DELETE CASCADE` to `messages.chat_id` → `chats(id)`
- Updates the `cleanup_user_storage` function for better error handling
- Creates missing tables if they don't exist (safety check)
- Removes orphaned foreign key constraints

**When to use**: Run this after the quick fix to ensure all foreign keys have proper CASCADE behavior.

## Migration Steps

### Step 1: Run the Quick Fix

1. Open your Supabase Dashboard
2. Navigate to **SQL Editor**
3. Copy and paste the contents of `supabase_quick_fix_cleanup_user_data.sql`
4. Click **Run** to execute the migration
5. Verify success (you should see a success message)

### Step 2: Test User Deletion

1. Try deleting a test user from the Supabase dashboard
2. The deletion should now work without errors

### Step 3: Run the Complete Fix (Recommended)

1. In the SQL Editor, copy and paste the contents of `supabase_migration_fix_user_deletion_complete.sql`
2. Click **Run** to execute the migration
3. This will add CASCADE to all foreign keys, making deletions automatic

## What Gets Deleted When a User is Deleted

With the CASCADE foreign keys in place, deleting a user will automatically delete:

1. **User Profile** (`user_profiles`) - User's profile information
2. **User Entitlements** (`user_entitlements`) - Subscription/plan information
3. **Notes** (`notes`) - All user's notes
4. **Note Sections** (`note_sections`) - Sections within notes (cascades from notes)
5. **Chats** (`chats`) - All user's chat conversations
6. **Messages** (`messages`) - All messages in those chats (cascades from chats and user)
7. **Storage Files** - User avatars, chat avatars, and chat images (via `cleanup_user_storage` trigger)

## Verification

After running the migrations, you can verify the foreign keys have CASCADE by running this query in the SQL Editor:

```sql
SELECT
  tc.table_schema,
  tc.table_name,
  kcu.column_name,
  ccu.table_schema AS foreign_table_schema,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
  ON rc.constraint_name = tc.constraint_name
  AND rc.constraint_schema = tc.table_schema
WHERE ccu.table_name = 'users'
  AND ccu.table_schema = 'auth'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name;
```

All `delete_rule` values should be `CASCADE` for tables that reference `auth.users`.

## Database Functions and Triggers

### `cleanup_user_data()`

- **Purpose**: Manually deletes user's chats and notes before user deletion
- **Trigger**: `cleanup_user_data_trigger` on `auth.users` (BEFORE DELETE)
- **Note**: With CASCADE foreign keys, this function is technically redundant, but kept as a safety net

### `cleanup_user_storage()`

- **Purpose**: Deletes user's storage files (avatars, images) before user deletion
- **Trigger**: `cleanup_user_storage_trigger` on `auth.users` (BEFORE DELETE)
- **Handles**: user-avatars, chat-avatars, and chat-images buckets

## Troubleshooting

### Error: "relation does not exist"

If you still get this error after running the migrations:

1. Check that the function uses qualified table names (`public.chats`, not `chats`)
2. Verify the tables exist in the `public` schema
3. Check the function's `search_path` setting

### Error: "foreign key constraint violation"

If you get foreign key errors:

1. Verify all foreign keys have `ON DELETE CASCADE`
2. Run the verification query above to check `delete_rule` values
3. Re-run the complete migration if needed

### User deletion succeeds but data remains

If user is deleted but related data remains:

1. Check that CASCADE foreign keys are properly set
2. Verify the triggers are active
3. Check Supabase logs for any trigger errors

## Related Files

- `supabase_quick_fix_cleanup_user_data.sql` - Quick fix for immediate error
- `supabase_migration_fix_user_deletion_complete.sql` - Complete migration with CASCADE
- `supabase_migration_fix_user_deletion_cascade.sql` - Alternative CASCADE-only migration
- `supabase_migration_fix_missing_chats_table.sql` - Creates missing tables if needed
- `supabase_schema.sql` - Current database schema reference

## Notes

- The migrations are **idempotent** - safe to run multiple times
- All operations use `IF EXISTS` checks to prevent errors
- Error handling is built into all functions to prevent deletion failures
- The migrations work with the existing schema and don't require data migration

## Last Updated

November 21, 2025

