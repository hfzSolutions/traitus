# Supabase Setup Guide for Traitus

This guide will help you set up Supabase for the Traitus AI Chat app.

## Prerequisites

- A Supabase account (sign up at https://supabase.com)
- Flutter installed on your machine

## Step 1: Create a Supabase Project

1. Go to https://supabase.com and sign in
2. Click "New Project"
3. Fill in the project details:
   - **Project Name**: `traitus` (or any name you prefer)
   - **Database Password**: Choose a strong password
   - **Region**: Select the closest region to your users
4. Click "Create new project"
5. Wait for the project to be set up (this may take a few minutes)

## Step 2: Set Up the Database Schema

1. In your Supabase project dashboard, go to the **SQL Editor** (left sidebar)
2. Click "New query"
3. Copy the entire contents of `supabase_schema.sql` from this repository
4. Paste it into the SQL editor
5. Click "Run" to execute the SQL script

This will create:
- `chats` table - stores chat conversations
- `messages` table - stores individual messages within chats
- `notes` table - stores user notes
- Row Level Security (RLS) policies to ensure users can only access their own data
- Indexes for better query performance

## Step 3: Configure Authentication

1. In your Supabase dashboard, go to **Authentication** → **Providers**
2. Make sure **Email** provider is enabled (it should be by default)
3. Optional: Configure additional auth providers if needed

### Email Templates (Optional but Recommended)

1. Go to **Authentication** → **Email Templates**
2. Customize the email templates for:
   - Confirm signup
   - Magic Link
   - Change Email Address
   - Reset Password

## Step 4: Get Your Supabase Credentials

1. In your Supabase dashboard, go to **Settings** → **API**
2. You'll need two values:
   - **Project URL** (looks like: `https://xxxxxxxxxxxxx.supabase.co`)
   - **anon/public key** (a long string starting with `eyJ...`)

## Step 5: Configure Your Flutter App

1. Create a `.env` file in the root of your Flutter project (if it doesn't exist)
2. Add your Supabase credentials:

```env
# OpenRouter API Key (for AI chat)
OPENROUTER_API_KEY=your_openrouter_api_key_here

# Supabase Configuration
SUPABASE_URL=https://xxxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

3. Replace the placeholder values with your actual credentials:
   - `SUPABASE_URL`: Your Project URL from Step 4
   - `SUPABASE_ANON_KEY`: Your anon/public key from Step 4

**Important**: Never commit your `.env` file to version control. It should be in your `.gitignore`.

## Step 6: Install Dependencies

Run the following command in your project root:

```bash
flutter pub get
```

## Step 7: Run the App

```bash
flutter run
```

The app will now:
1. Show a login/signup screen
2. Store all data in Supabase
3. Keep user data isolated (thanks to RLS policies)

## Troubleshooting

### "User not authenticated" errors

- Make sure you're signed in
- Check that your Supabase credentials are correct in `.env`
- Verify the SQL schema was executed successfully

### Can't see data in Supabase

- Go to **Database** → **Tables** in Supabase dashboard
- Click on a table (e.g., `chats`, `messages`, `notes`)
- You should see your data there
- If RLS is enabled, you might need to disable it temporarily to view all data, or use the "Service role" key

### Authentication issues

- Check **Authentication** → **Users** in Supabase to see registered users
- Make sure email confirmation is not required (or handle it in your app)
- Check the browser console or app logs for detailed error messages

### Database connection errors

- Verify your `SUPABASE_URL` and `SUPABASE_ANON_KEY` are correct
- Make sure you're using the **anon/public** key, not the service role key
- Check your internet connection

## Security Notes

1. **Row Level Security (RLS)** is enabled on all tables to ensure users can only access their own data
2. The **anon/public key** is safe to use in client apps (it's designed for this purpose)
3. Never use the **service role key** in client code
4. All user data is automatically isolated by the `user_id` field

## Database Schema Overview

### `chats` table
- Stores chat conversation metadata
- Each chat belongs to a user
- Contains: id, user_id, name, description, model, last_message, last_message_time, created_at

### `messages` table
- Stores individual messages within chats
- Each message belongs to a chat and a user
- Contains: id, chat_id, user_id, role, content, created_at, is_pending, has_error

### `notes` table
- Stores user notes
- Each note belongs to a user
- Contains: id, user_id, title, content, created_at

## Migration from SharedPreferences

If you have existing data in SharedPreferences, it will not be automatically migrated. You'll start with a fresh database in Supabase. To migrate:

1. Export your data from SharedPreferences before updating
2. Sign up/sign in to the new version
3. Manually import your data through the app (or write a migration script)

## Support

If you encounter any issues:
1. Check the Supabase documentation: https://supabase.com/docs
2. Check Flutter Supabase documentation: https://supabase.com/docs/guides/getting-started/tutorials/with-flutter
3. Review the error messages in your app logs
4. Check the Supabase dashboard logs: **Logs** section in the sidebar

