# AI Response Style Settings Feature

## Overview

This feature allows users to customize how the AI responds to them using user-friendly, non-technical settings. Instead of manually editing system prompts, users can select from preset options that automatically configure the AI's behavior.

## User-Friendly Settings

### 1. Response Tone
Controls the conversational tone of the AI:
- **Friendly & Warm** - Warm, friendly, and approachable responses
- **Professional** - Professional and formal tone
- **Casual & Relaxed** - Casual and relaxed conversation style
- **Formal** - Formal language with appropriate distance
- **Enthusiastic** - Enthusiastic and energetic responses

### 2. Response Length
Controls how detailed the AI's responses are:
- **Brief** - Quick, concise answers straight to the point
- **Balanced** - Moderate detail, good for general use
- **Detailed** - Comprehensive and thorough explanations

### 3. Writing Style
Controls the language complexity and approach:
- **Simple** - Easy-to-understand language for all users
- **Technical** - Uses technical terminology when appropriate
- **Creative** - Engaging and creative language
- **Analytical** - Structured and analytical explanations

### 4. Use Emojis
- Toggle to allow or disallow emojis in AI responses
- Adds personality and visual appeal when enabled

## Implementation Details

### Database Schema

New columns added to `ai_chats` table:
```sql
response_tone TEXT DEFAULT 'friendly'
response_length TEXT DEFAULT 'balanced'
writing_style TEXT DEFAULT 'simple'
use_emojis BOOLEAN DEFAULT FALSE
```

### Model Changes

**File: `lib/models/ai_chat.dart`**

Added fields:
- `responseTone: String`
- `responseLength: String`
- `writingStyle: String`
- `useEmojis: bool`

New method:
- `getEnhancedSystemPrompt()` - Generates a system prompt with response style guidelines appended

### UI Changes

**File: `lib/ui/chat_page.dart`**

The chat edit modal (`_EditChatModal`) now includes:
- **Collapsible Response Style Settings** - Hidden by default to keep UI clean
- **Expandable section** with tune icon and description
- Dropdown for selecting tone (when expanded)
- Dropdown for selecting response length (when expanded)
- Dropdown for selecting writing style (when expanded)
- Switch for enabling/disabling emojis (when expanded)

The settings are optional and collapsible to avoid overwhelming users with too many options at once.

### System Prompt Enhancement

The `getEnhancedSystemPrompt()` method in `AiChat` automatically generates enhanced system prompts:

```dart
String getEnhancedSystemPrompt() {
  final buffer = StringBuffer(description);
  buffer.write('\n\nResponse Style Guidelines:');
  
  // Adds specific instructions based on selected preferences
  // - Tone guidance
  // - Length guidance
  // - Style guidance
  // - Emoji guidance
  
  return buffer.toString();
}
```

Example output:
```
You are a helpful coding assistant specialized in Flutter and Dart.

Response Style Guidelines:
- Use a warm, friendly, and approachable tone
- Provide balanced responses with appropriate detail
- Use simple, easy-to-understand language
- Avoid using emojis in responses
```

### Integration with ChatProvider

**File: `lib/ui/chat_list_page.dart`**

When creating a `ChatProvider` instance, it now uses:
```dart
ChatProvider(
  chatId: chat.id,
  model: chat.model,
  systemPrompt: chat.getEnhancedSystemPrompt(), // Enhanced!
)
```

## Migration

### Running the Migration

Execute the migration SQL on your Supabase database:
```bash
psql -h your-supabase-host -U postgres -d postgres < supabase_migration_add_response_style.sql
```

Or through Supabase Dashboard:
1. Go to SQL Editor
2. Copy contents of `supabase_migration_add_response_style.sql`
3. Execute the query

### Backward Compatibility

✅ **Fully backward compatible**
- Existing chats automatically get default values
- Default values match the original behavior
- No data loss or breaking changes

## User Guide

### How to Edit Response Style

1. **Open a chat** you want to customize
2. **Tap the chat name or avatar** in the app bar, or
3. **Tap the three-dot menu** → "Edit Chat Settings"
4. **Tap on "Response Style Settings"** to expand the section
5. **Select your preferences**:
   - Choose a tone that matches your needs
   - Pick a response length
   - Select a writing style
   - Toggle emojis on/off
6. **Tap "Save Changes"**

The AI will immediately start using your new preferences in all future responses!

> 💡 **Tip:** The Response Style settings are collapsible to keep the interface clean. Simply tap the section to expand or collapse it.

### When to Use Each Setting

#### Tone Selection
- **Friendly** - Best for casual conversations and learning
- **Professional** - Ideal for work-related queries
- **Casual** - When you want a relaxed, informal chat
- **Formal** - For academic or official communications
- **Enthusiastic** - When you want motivation and energy

#### Length Selection
- **Brief** - When you need quick answers or are short on time
- **Balanced** - Good default for most situations
- **Detailed** - When learning new concepts or need thorough explanations

#### Style Selection
- **Simple** - Best for beginners or complex topics explained simply
- **Technical** - When you're comfortable with jargon and want precision
- **Creative** - For brainstorming, storytelling, and creative work
- **Analytical** - For data analysis, research, and structured thinking

## Examples

### Example 1: Learning Assistant
**Settings:**
- Tone: Friendly
- Length: Detailed
- Style: Simple
- Emojis: ✓ Enabled

**Result:** Patient, thorough explanations in easy-to-understand language with encouraging emojis.

### Example 2: Professional Code Review
**Settings:**
- Tone: Professional
- Length: Balanced
- Style: Technical
- Emojis: ✗ Disabled

**Result:** Professional, technical feedback with appropriate detail and no emojis.

### Example 3: Creative Writing Partner
**Settings:**
- Tone: Enthusiastic
- Length: Detailed
- Style: Creative
- Emojis: ✓ Enabled

**Result:** Energetic, creative suggestions with rich language and expressive emojis.

## Benefits

### For Users
✅ **Easy to understand** - No technical jargon required
✅ **Quick to configure** - Select from clear, descriptive options
✅ **Consistent experience** - Settings apply to all conversations in that chat
✅ **Flexible** - Change settings anytime to match your needs
✅ **Visual feedback** - See exactly what each option does

### For Developers
✅ **Clean separation** - Response style separate from core AI behavior
✅ **Easy to extend** - Add new style options easily
✅ **Maintainable** - Centralized prompt generation
✅ **Type-safe** - All options are defined in code
✅ **Testable** - Can test different style combinations

## Future Enhancements

Possible future additions:
- **Expertise Level** - Beginner, Intermediate, Advanced
- **Creativity Level** - Factual, Balanced, Creative
- **Example Preference** - With examples, Without examples
- **Code Style** - Commented, Minimal, Best practices
- **Explanation Style** - Teach why, Just the answer

## Technical Notes

### Why This Approach?

Instead of exposing technical parameters like `temperature`, `top_p`, etc., we:
1. **Present options users understand** - "Friendly" vs "temperature: 0.7"
2. **Guide behavior through prompts** - More reliable than parameter tuning
3. **Keep it simple** - Fewer options that work well together
4. **Match user intent** - Settings map to what users actually want

### System Prompt Construction

The system prompt is constructed in two parts:
1. **Base description** - The chat's core purpose and expertise
2. **Style guidelines** - Appended based on user preferences

This ensures:
- The AI's core purpose remains clear
- Style preferences don't conflict with the base description
- Users can change style without losing the AI's expertise

### Performance Considerations

- ✅ No performance impact - Prompt generation is instant
- ✅ Same API calls - No additional OpenRouter requests
- ✅ Efficient storage - Only 4 additional database columns
- ✅ Fast queries - Simple string/boolean columns

## Files Modified

1. **lib/models/ai_chat.dart** - Added response style fields and enhanced prompt method
2. **lib/ui/chat_page.dart** - Added UI for editing response styles
3. **lib/ui/chat_list_page.dart** - Updated to use enhanced system prompt
4. **supabase_migration_add_response_style.sql** - Database migration

## Testing Checklist

- [ ] Create a new chat and set response styles
- [ ] Edit an existing chat's response styles
- [ ] Verify settings persist after app restart
- [ ] Test each tone option with the same question
- [ ] Test brief vs detailed response lengths
- [ ] Verify emoji toggle works correctly
- [ ] Check that style changes apply immediately to new messages
- [ ] Ensure system prompt is correctly enhanced
- [ ] Verify backward compatibility with existing chats

## Support

If users have questions about which settings to use, recommend starting with:
- **Tone:** Friendly
- **Length:** Balanced
- **Style:** Simple
- **Emojis:** Based on personal preference

They can experiment from there to find what works best for them!

