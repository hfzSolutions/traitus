# Changelog: Model Tracking Implementation

## Date: October 31, 2025

## Summary

Implemented per-message model tracking system. Each assistant message now records which AI model was used to generate it, providing transparency and enabling future multi-model support.

---

## Changes Made

### 1. Database Schema Updates

#### File: `supabase_schema.sql`
- **Added**: `model TEXT` field to the `messages` table
- **Purpose**: Store which AI model generated each assistant response

#### File: `supabase_migration_add_model_to_messages.sql` (NEW)
- **Created**: Migration script for existing databases
- **Purpose**: Allow users with existing databases to add the model field without recreating tables

### 2. Model Classes

#### File: `lib/models/chat_message.dart`
- **Added**: `model` field (String?, nullable)
- **Updated**: Constructor to accept optional `model` parameter
- **Updated**: `copyWith()` method to include `model` parameter
- **Purpose**: Track which model generated each message

### 3. Database Service

#### File: `lib/services/database_service.dart`
- **Updated**: `createMessage()` - Now saves model field to database
- **Updated**: `updateMessage()` - Now updates model field in database
- **Updated**: `_chatMessageFromJson()` - Now reads model field from database
- **Purpose**: Persist and retrieve model information

### 4. API Service

#### File: `lib/services/openrouter_api.dart`
- **Removed**: Hardcoded `_defaultModel = 'openrouter/auto'` constant
- **Added**: `_model` getter that reads from `OPENROUTER_MODEL` env variable
- **Added**: Validation to throw error if `OPENROUTER_MODEL` is not configured
- **Updated**: `createChatCompletion()` to use `_model` getter instead of hardcoded default
- **Purpose**: Enforce configuration via environment variables

### 5. Providers

#### File: `lib/providers/chat_provider.dart`
- **Added**: Import for `flutter_dotenv`
- **Updated**: Constructor to use `dotenv.env['OPENROUTER_MODEL']` instead of hardcoded default
- **Added**: Validation to throw error if model is not configured
- **Updated**: `sendUserMessage()` - Assistant messages now include `model: _model`
- **Updated**: Error message creation to include `model: _model`
- **Purpose**: Save model information with each assistant response

#### File: `lib/providers/chats_list_provider.dart`
- **Added**: Import for `flutter_dotenv`
- **Updated**: Default chat creation to use `dotenv.env['OPENROUTER_MODEL']`
- **Added**: Validation for model configuration
- **Purpose**: Use environment variable for default chat model

### 6. UI Components

#### File: `lib/ui/chat_list_page.dart`
- **Added**: Import for `flutter_dotenv`
- **Updated**: `_createChat()` method to use `dotenv.env['OPENROUTER_MODEL']`
- **Added**: Error handling for missing model configuration
- **Purpose**: Use environment variable when creating new chats

### 7. Documentation

#### File: `README.md`
- **Updated**: Configuration section to document `OPENROUTER_MODEL` variable
- **Added**: Model tracking feature description
- **Updated**: .env example to include `OPENROUTER_MODEL`
- **Updated**: Database schema description to mention model field
- **Added**: Link to MODEL_TRACKING.md

#### File: `MODEL_TRACKING.md` (NEW)
- **Created**: Comprehensive documentation of model tracking feature
- **Includes**: 
  - Feature overview
  - Database schema details
  - Migration instructions
  - Usage examples
  - Use cases and analytics examples
  - Future enhancement ideas

---

## Breaking Changes

### Required Configuration

**BEFORE**: App would fall back to `'openrouter/auto'` if no model was specified

**AFTER**: App requires `OPENROUTER_MODEL` to be set in `.env` file

### Migration Required

**For Existing Databases**: Run the migration script
```sql
ALTER TABLE messages ADD COLUMN IF NOT EXISTS model TEXT;
```

---

## Benefits

1. **Transparency**: Users know which model generated each response
2. **Debugging**: Easier to identify model-specific issues
3. **Compliance**: Track model usage for audit purposes
4. **Analytics**: Query and analyze which models are used
5. **Future-Ready**: Prepares system for multi-model support
6. **No Hardcoded Values**: All models configured via environment

---

## Environment Variables

### Required
```bash
OPENROUTER_MODEL=anthropic/claude-3-sonnet
```

### Optional (for reference)
```bash
OPENROUTER_API_KEY=your_key_here          # Required
OPENROUTER_BASE_URL=https://...           # Optional
OPENROUTER_SITE_URL=https://...           # Optional  
OPENROUTER_APP_NAME=Traitus AI Chat       # Optional
```

---

## Testing Checklist

- [ ] Run migration script on existing database
- [ ] Set `OPENROUTER_MODEL` in `.env` file
- [ ] Create new chat - verify model is saved
- [ ] Send message - verify assistant response includes model
- [ ] Check database - verify model field is populated
- [ ] Verify app throws error if `OPENROUTER_MODEL` is missing

---

## Files Created

1. `supabase_migration_add_model_to_messages.sql` - Database migration
2. `MODEL_TRACKING.md` - Feature documentation

---

## Files Modified

1. `supabase_schema.sql` - Added model field to messages table
2. `lib/models/chat_message.dart` - Added model property
3. `lib/services/database_service.dart` - Handle model field
4. `lib/services/openrouter_api.dart` - Use env variable for model
5. `lib/providers/chat_provider.dart` - Save model with messages
6. `lib/providers/chats_list_provider.dart` - Use env variable
7. `lib/ui/chat_list_page.dart` - Use env variable
8. `README.md` - Updated documentation

---

## Migration Instructions

### For New Projects
1. Set `OPENROUTER_MODEL` in `.env` file
2. Run `supabase_schema.sql` (already includes model field)
3. Done!

### For Existing Projects
1. Set `OPENROUTER_MODEL` in `.env` file
2. Run `supabase_migration_add_model_to_messages.sql` in Supabase SQL Editor
3. Update Flutter dependencies: `flutter pub get`
4. Restart app
5. Done!

---

## Future Enhancements

Possible future features (not implemented yet):
- Display model badge in chat UI
- Per-message model selection
- Model comparison view
- Usage analytics dashboard
- Cost tracking per model
- Model performance metrics

