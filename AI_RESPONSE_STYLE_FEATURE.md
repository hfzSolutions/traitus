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
- **Brief** - Quick, concise answers straight to the point (2-4 sentences, ~200-300 words)
- **Balanced** - Moderate detail, good for general use (4-8 sentences, ~400-600 words)
- **Detailed** - Comprehensive and thorough explanations (8+ sentences, ~600-1000 words)

**Note:** The response length setting automatically adjusts the token limit to prevent cut-off responses. Brief responses use lower token limits (300-500 tokens), while detailed responses get higher limits (up to 1500 tokens) to ensure complete answers.

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
  // - Length guidance (with explicit token limit awareness)
  // - Style guidance
  // - Emoji guidance
  // - Instructions to complete thoughts within limits
  
  return buffer.toString();
}
```

Example output:
```
You are a helpful coding assistant specialized in Flutter and Dart.

Response Style Guidelines:
- Use a warm, friendly, and approachable tone
- Provide balanced responses with appropriate detail (aim for 4-8 sentences)
- If you reach the response limit, ensure your last sentence is complete and meaningful
- Use simple, easy-to-understand language
- Avoid using emojis in responses
- Always complete your thoughts within the response limit - do not cut off mid-sentence
- If approaching the limit, conclude with a complete sentence rather than starting a new point
```

**Key Features:**
- Explicit instructions to complete thoughts within token limits
- Guidance to avoid mid-sentence cutoffs
- Instructions to prioritize important information first (for brief responses)
- Clear expectations about response length based on the setting

### Integration with ChatProvider

**File: `lib/ui/chat_list_page.dart`**

When creating a `ChatProvider` instance, it now uses:
```dart
ChatProvider(
  chatId: chat.id,
  model: chat.model,
  systemPrompt: chat.getEnhancedSystemPrompt(), // Enhanced!
  responseLength: chat.responseLength, // Passed for dynamic token calculation
)
```

**File: `lib/providers/chat_provider.dart`**

The `ChatProvider` now:
1. Receives the `responseLength` parameter
2. Automatically calculates appropriate `max_tokens` based on response length:
   - **Brief**: 50% of base max_tokens (300-500 tokens)
   - **Balanced**: Base max_tokens (default: 800 tokens)
   - **Detailed**: 150% of base max_tokens (up to 1500 tokens)
3. Passes the calculated `max_tokens` to the OpenRouter API

This ensures responses are appropriately sized and complete, preventing cut-off text.

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
- **Brief** - When you need quick answers or are short on time. Automatically uses lower token limits (300-500 tokens) to ensure concise, complete responses.
- **Balanced** - Good default for most situations. Uses standard token limits (800 tokens default) for well-rounded answers.
- **Detailed** - When learning new concepts or need thorough explanations. Uses higher token limits (up to 1500 tokens) to allow comprehensive responses without cut-offs.

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

## Token Management & Response Length

### Dynamic Token Calculation

The system automatically adjusts `max_tokens` based on the response length setting to prevent cut-off responses:

**Implementation: `lib/services/openrouter_api.dart`**

```dart
static int getMaxTokensForResponseLength(String? responseLength, {int? baseMaxTokens}) {
  final base = baseMaxTokens ?? 800;
  
  switch (responseLength?.toLowerCase()) {
    case 'brief':
      // Brief responses: 300-400 tokens (roughly 200-300 words)
      return (base * 0.5).round().clamp(300, 500);
    case 'balanced':
      // Balanced responses: use base value
      return base;
    case 'detailed':
      // Detailed responses: allow more tokens (but still reasonable for mobile)
      return (base * 1.5).round().clamp(base, 1500);
    default:
      return base;
  }
}
```

### Benefits

1. **Prevents Cut-Offs**: Appropriate token limits ensure responses complete properly
2. **Mobile-Optimized**: Brief responses stay concise for mobile screens
3. **Complete Thoughts**: System prompt instructions ensure sentences finish properly
4. **Configurable Base**: Base token limit can be set via `OPENROUTER_MAX_TOKENS` environment variable

### Configuration

The base token limit can be configured in your `.env` file:
```bash
# Default: 800 tokens (suitable for mobile)
OPENROUTER_MAX_TOKENS=800
```

The response length setting then automatically adjusts from this base:
- Brief: ~400 tokens (50% of base)
- Balanced: 800 tokens (base value)
- Detailed: ~1200 tokens (150% of base)

## Technical Notes

### Why This Approach?

Instead of exposing technical parameters like `temperature`, `top_p`, etc., we:
1. **Present options users understand** - "Friendly" vs "temperature: 0.7"
2. **Guide behavior through prompts** - More reliable than parameter tuning
3. **Keep it simple** - Fewer options that work well together
4. **Match user intent** - Settings map to what users actually want
5. **Prevent cut-offs** - Dynamic token limits + prompt instructions ensure complete responses

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

1. **lib/models/ai_chat.dart** - Added response style fields and enhanced prompt method with cut-off prevention instructions
2. **lib/ui/chat_page.dart** - Added UI for editing response styles
3. **lib/ui/chat_list_page.dart** - Updated to use enhanced system prompt and pass responseLength
4. **lib/providers/chat_provider.dart** - Added responseLength parameter and dynamic max_tokens calculation
5. **lib/services/openrouter_api.dart** - Added `getMaxTokensForResponseLength()` method and maxTokens getter
6. **supabase_migration_add_response_style.sql** - Database migration

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
- [ ] **Test token limits**: Verify brief responses use lower token limits (300-500 tokens)
- [ ] **Test token limits**: Verify balanced responses use base token limit (800 tokens)
- [ ] **Test token limits**: Verify detailed responses use higher token limits (up to 1500 tokens)
- [ ] **Test cut-off prevention**: Verify responses complete properly without mid-sentence cut-offs
- [ ] **Test mobile optimization**: Verify brief responses are concise and complete on mobile screens
- [ ] **Test environment variable**: Change `OPENROUTER_MAX_TOKENS` and verify it affects token calculations

## Support

If users have questions about which settings to use, recommend starting with:
- **Tone:** Friendly
- **Length:** Balanced
- **Style:** Simple
- **Emojis:** Based on personal preference

They can experiment from there to find what works best for them!

