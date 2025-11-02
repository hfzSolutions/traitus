# AI Model Configuration Guide

## Overview

The application now loads AI models from environment variables instead of hardcoding them. This allows you to easily configure which models are used for each type of AI assistant without changing the code.

## Implementation

### New File: `lib/config/default_ai_config.dart`

This configuration service manages all default AI model settings:

- **`getModel(String assistantType)`**: Returns the model for a specific assistant type
- **`getAvailableAIChats()`**: Returns all AI chat configurations with models loaded from env
- **`getChatConfig(String chatId)`**: Gets configuration for a specific chat

### Model Resolution Logic

```
1. Check for specific override: DEFAULT_MODEL_<TYPE>
   ↓ (if not found)
2. Check for category default: DEFAULT_MODEL_FREE or DEFAULT_MODEL_PREMIUM
   ↓ (if not found)
3. Use global fallback: DEFAULT_MODEL
   ↓ (if not found)
4. Use hardcoded fallback: "minimax/minimax-m2:free"
```

## Environment Variables

### Basic Setup (Recommended)

```bash
# Free tier model for most assistants
DEFAULT_MODEL_FREE=minimax/minimax-m2:free

# Premium model for advanced assistants
DEFAULT_MODEL_PREMIUM=minimax/minimax-m2:free

# General fallback
DEFAULT_MODEL=minimax/minimax-m2:free
```

### Advanced Setup (Per-Assistant Override)

```bash
# Override individual assistant models
DEFAULT_MODEL_CODING=anthropic/claude-3.5-sonnet
DEFAULT_MODEL_CREATIVE=google/gemini-2.0-flash-exp:free
DEFAULT_MODEL_RESEARCH=anthropic/claude-3.5-sonnet
DEFAULT_MODEL_PRODUCTIVITY=minimax/minimax-m2:free
DEFAULT_MODEL_LEARNING=minimax/minimax-m2:free
DEFAULT_MODEL_BUSINESS=minimax/minimax-m2:free
```

## Default Model Assignment

By default (without any env variables set):

| Assistant | Category | Default Model |
|-----------|----------|---------------|
| Coding | Free | minimax/minimax-m2:free |
| Creative | Free | minimax/minimax-m2:free |
| Research | Free | minimax/minimax-m2:free |
| Business | Free | minimax/minimax-m2:free |
| Productivity | Premium | minimax/minimax-m2:free |
| Learning | Premium | minimax/minimax-m2:free |

## Usage Examples

### Example 1: All Free Models
```bash
DEFAULT_MODEL=minimax/minimax-m2:free
```
Result: All assistants use the free model.

### Example 2: Coding Uses Claude
```bash
DEFAULT_MODEL_FREE=minimax/minimax-m2:free
DEFAULT_MODEL_CODING=anthropic/claude-3.5-sonnet
```
Result: Coding assistant uses Claude, others use free model.

### Example 3: Premium for All
```bash
DEFAULT_MODEL=minimax/minimax-m2:free
```
Result: All assistants use GPT-4o (expensive!).

## Code Changes Summary

### Before (Hardcoded):
```dart
// In database_service.dart
'coding': {
  'name': 'Coding Assistant',
  'model': 'minimax/minimax-m2:free',  // Hardcoded!
  ...
},
```

### After (From Environment):
```dart
// In database_service.dart
import 'package:traitus/config/default_ai_config.dart';

// Uses DefaultAIConfig which reads from env
final config = DefaultAIConfig.getChatConfig(chatId);
```

## Files Modified

1. **`lib/config/default_ai_config.dart`** (NEW)
   - Central configuration service
   - Reads from environment variables
   - Provides fallback defaults

2. **`lib/ui/onboarding_page.dart`**
   - Removed hardcoded model map
   - Now uses `DefaultAIConfig.getAvailableAIChats()`

3. **`lib/services/database_service.dart`**
   - Removed `_getAvailableAIChats()` method
   - Now uses `DefaultAIConfig.getChatConfig()`

## Benefits

✅ **Flexible Configuration**: Change models without code changes  
✅ **Environment-Specific**: Different models for dev/staging/prod  
✅ **Cost Control**: Easily switch to free models to save costs  
✅ **Per-Assistant Control**: Fine-grained model selection  
✅ **Easy Testing**: Test with different models quickly  
✅ **Centralized**: Single source of truth for model configs  

## Testing

To test different models:

1. Update your `.env` file with desired models
2. Restart the app
3. Create a new user account
4. Go through onboarding
5. Check that AI assistants use the correct models

## Migration Notes

- **Existing installations**: No migration needed - falls back to sensible defaults
- **Existing chats**: Keep their original models (not affected)
- **New chats**: Use the configured models from environment

## Troubleshooting

**Q: My model changes aren't taking effect**  
A: Make sure to restart the app after changing `.env` file

**Q: I get an error about missing models**  
A: Check that your model names are correct for OpenRouter API

**Q: How do I know which model is being used?**  
A: During onboarding, the model name is displayed under each AI assistant

**Q: Can I change the model after onboarding?**  
A: Yes, users can edit any chat and change its model in the settings

