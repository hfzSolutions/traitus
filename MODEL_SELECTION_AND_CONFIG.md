# Model Selection and Configuration System

This document describes the complete model selection and configuration system in Traitus, including database-driven configuration, user model selection, and data integrity.

## Overview

The app now supports:
- ✅ **User model selection**: Users can choose different AI models for each chat
- ✅ **Database-driven configuration**: All model settings stored in database (no environment variables)
- ✅ **Model management**: Models are managed in the `models` table
- ✅ **Data integrity**: Validation ensures config values reference valid models
- ✅ **Row Level Security**: Proper access control for configuration and models

## Database Schema

### Models Table

Stores all available AI models that users can select from.

```sql
CREATE TABLE models (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  model_id text NOT NULL UNIQUE,  -- OpenRouter model ID (e.g., "openai/gpt-4o-mini")
  provider text NOT NULL DEFAULT 'openrouter',
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
```

**Key Points:**
- All models use OpenRouter (`provider = 'openrouter'`)
- `model_id` is the OpenRouter model identifier
- Only active models (`is_active = true`) are shown to users
- Models are managed via Supabase dashboard or service role API

### App Config Table

Stores default model configurations for the application.

```sql
CREATE TABLE app_config (
  id uuid PRIMARY KEY,
  key text NOT NULL UNIQUE,
  value text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
```

**Configuration Keys:**
- `default_model`: Default model for all chats (required)
- `onboarding_model`: Model used for onboarding/assistant finding (optional, falls back to default_model)
- `quick_reply_model`: Model used for quick reply generation (optional, falls back to default_model)

**Key Points:**
- All model values must reference valid `model_id` values from the `models` table
- Validation trigger ensures data integrity
- Managed via Supabase dashboard or service role API

### Chats Table

Each chat can have its own selected model.

```sql
ALTER TABLE chats ADD COLUMN model text;
```

**Key Points:**
- `model` field stores the `model_id` from the `models` table
- If `model` is null, the chat uses `default_model` from `app_config`
- Users can change the model when creating or editing a chat

## Migration Files

Run these migrations in order:

1. **`supabase_migration_restore_model_selection.sql`**
   - Creates `models` table
   - Adds `model` field to `chats` table
   - Inserts default models

2. **`supabase_migration_add_app_config_models.sql`**
   - Creates `app_config` table
   - Inserts default model configurations
   - Sets up triggers for `updated_at`

3. **`supabase_migration_validate_app_config_models.sql`**
   - Creates validation functions
   - Adds trigger to ensure app_config model values exist in models table
   - Validates existing data

4. **`supabase_migration_add_rls_app_config_models.sql`**
   - Enables RLS on both tables
   - Allows authenticated users to read
   - Restricts writes to service role only

## Row Level Security (RLS)

### App Config Table

- **READ**: All authenticated users can read (needed to know which models to use)
- **WRITE**: Only service role can modify (prevents users from changing config)

### Models Table

- **READ**: All authenticated users can read (needed to see available models)
- **WRITE**: Only service role can modify (prevents users from modifying model list)

### To Allow Admin Access (Optional)

If you want to allow admin users to manage these tables, add policies:

```sql
CREATE POLICY "Allow admins to manage app_config"
  ON app_config FOR ALL TO authenticated
  USING (auth.jwt() ->> 'user_role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'user_role' = 'admin');
```

## Application Code

### AppConfigService

Singleton service that manages app configuration from the database.

**Key Methods:**
- `initialize()`: Loads config from database into cache (called on app startup)
- `getDefaultModel()`: Gets default model (async, fetches from DB if needed)
- `getOnboardingModel()`: Gets onboarding model (falls back to default)
- `getQuickReplyModel()`: Gets quick reply model (falls back to default)
- `getCachedDefaultModel()`: Gets default model from cache (synchronous)

**Caching:**
- Config values are cached for 5 minutes
- Cache is initialized on app startup in `main()`
- Cache auto-refreshes if stale or missing

### Model Selection UI

Users can select models when creating or editing chats:

1. Open chat form (create or edit)
2. Expand "Advanced Settings"
3. Select model from dropdown
4. Model list is loaded from `models` table
5. Selected model is saved to chat's `model` field

### ChatProvider

Uses the model from the chat:
- If chat has a `model`, uses that
- If chat `model` is null, uses `default_model` from `app_config`
- Model can be updated when chat settings are changed

## Data Flow

### App Startup

1. App loads environment variables (for API keys, etc.)
2. Initializes Supabase connection
3. **Calls `AppConfigService.instance.initialize()`** - loads model configs from DB
4. Cache is now ready for use

### Creating a Chat

1. User opens chat form
2. System loads models from `models` table
3. User selects a model (or uses default)
4. Chat is created with selected `model_id`
5. ChatProvider uses the chat's model for API calls

### Sending a Message

1. ChatProvider gets model from chat (or default_model)
2. Model is passed to OpenRouterApi
3. API call uses the selected model
4. Response is saved with the model used

## Configuration Management

### Adding a New Model

1. Insert into `models` table via Supabase dashboard:
```sql
INSERT INTO models (name, model_id, provider, description, is_active)
VALUES ('New Model', 'provider/model-id', 'openrouter', 'Description', true);
```

2. Model will appear in the dropdown for users

### Changing Default Model

1. Update `app_config` table via Supabase dashboard:
```sql
UPDATE app_config 
SET value = 'new-model-id' 
WHERE key = 'default_model';
```

2. **Important**: The new model_id must exist in the `models` table (validation will prevent invalid values)

3. Cache will refresh within 5 minutes, or restart the app

### Deactivating a Model

```sql
UPDATE models 
SET is_active = false 
WHERE model_id = 'model-to-hide';
```

- Model will no longer appear in dropdowns
- Existing chats using this model will continue to work
- Validation will prevent setting it as default_model

## Validation

The system includes automatic validation:

1. **Trigger Validation**: When updating `app_config` with model values:
   - Checks if model_id exists in `models` table
   - Checks if model is active
   - Raises error if invalid

2. **Existing Data Check**: Migration validates existing configs and warns about invalid values

## Error Handling

### Missing Default Model

If `default_model` is not set in `app_config`:
- App will throw error on startup
- Error message: "Missing default_model in app_config table. Please set it in the database."

### Invalid Model Reference

If `app_config` references a model that doesn't exist:
- Database trigger will prevent the update
- Error message: "Model 'X' does not exist in models table or is not active."

### Cache Not Initialized

If cache is accessed before initialization:
- Synchronous methods will throw error
- Async methods will fetch from database automatically

## Best Practices

1. **Always add models to `models` table first**, then reference them in `app_config`
2. **Use active models only** - deactivate instead of deleting
3. **Test model changes** in development before production
4. **Monitor cache** - config changes take effect within 5 minutes or on app restart
5. **Backup config** before making changes

## Migration Checklist

- [ ] Run `supabase_migration_restore_model_selection.sql`
- [ ] Run `supabase_migration_add_app_config_models.sql`
- [ ] Run `supabase_migration_validate_app_config_models.sql`
- [ ] Run `supabase_migration_add_rls_app_config_models.sql`
- [ ] Verify models are inserted correctly
- [ ] Verify app_config has default_model set
- [ ] Test model selection in UI
- [ ] Test that default model works when chat has no model

## Troubleshooting

### "Model cache not initialized" error
- **Solution**: Ensure `AppConfigService.instance.initialize()` is called in `main()`
- Check that Supabase connection is established before initialization

### "Missing default_model" error
- **Solution**: Run `supabase_migration_add_app_config_models.sql` to insert default config
- Or manually insert: `INSERT INTO app_config (key, value) VALUES ('default_model', 'minimax/minimax-m2:free');`

### Model not appearing in dropdown
- **Solution**: Check that model exists in `models` table and `is_active = true`
- Verify RLS policies allow reading from `models` table

### Cannot update app_config
- **Solution**: Use service role API key or Supabase dashboard
- Regular users cannot modify app_config (by design for security)

## Summary

The model selection system provides:
- ✅ Flexible model selection per chat
- ✅ Database-driven configuration (no env vars for models)
- ✅ Data integrity through validation
- ✅ Secure access control via RLS
- ✅ Caching for performance
- ✅ Automatic fallbacks for missing configs

All model configurations are now managed in the database, making it easy to update models without code changes or deployments.

