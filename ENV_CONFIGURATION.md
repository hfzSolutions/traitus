# Environment Variables Configuration

This document describes all the environment variables used in the Traitus application.

## Required Variables

### Supabase Configuration
```bash
SUPABASE_URL=your_supabase_url_here
SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

### OpenRouter API Configuration
```bash
OPENROUTER_API_KEY=your_openrouter_api_key_here
# Optional: Base maximum tokens for AI responses (default: 800, suitable for mobile)
# This is the base value used for "balanced" response length
# The system automatically adjusts this based on user's response length preference:
#   - Brief: 50% of base (300-500 tokens)
#   - Balanced: Base value (800 tokens default)
#   - Detailed: 150% of base (up to 1500 tokens)
# Lower values = shorter responses, higher values = longer responses
OPENROUTER_MAX_TOKENS=800
```

**How Token Limits Work:**
- The `OPENROUTER_MAX_TOKENS` value serves as the base for "balanced" responses
- When users select "brief" response length, the system uses ~50% of this value (300-500 tokens)
- When users select "detailed" response length, the system uses ~150% of this value (up to 1500 tokens)
- This prevents cut-off responses by setting appropriate limits for each preference
- The system prompt also includes instructions to complete thoughts within limits

## Required: AI Model Configuration

The app uses a single AI model configured via environment variable. This model is used for all AI interactions.

```bash
# Required: The AI model to use for all chats
OPENROUTER_MODEL=minimax/minimax-m2:free
```

### Popular Model Options

You can use any model available on OpenRouter. Some popular options:

- `minimax/minimax-m2:free` - Fast and free
- `google/gemini-2.0-flash-exp:free` - Google's Gemini (free)
- `anthropic/claude-3.5-sonnet` - Anthropic's Claude (premium)
- `openai/gpt-4o-mini` - OpenAI's GPT-4 Mini (premium)

For a full list of available models, visit: https://openrouter.ai/models

**Note:** The app uses this single model for all chats. There is no per-chat model selection.

## Setup Instructions

1. Copy your `.env` file (or create one)
2. Add the required Supabase and OpenRouter credentials
3. Set `OPENROUTER_MODEL` to your preferred model
4. Restart the application

## Token Management

### Response Length & Token Limits

The application automatically manages token limits based on user preferences:

1. **Base Limit**: Set via `OPENROUTER_MAX_TOKENS` (default: 800 tokens)
2. **Dynamic Adjustment**: Token limits adjust based on response length setting:
   - **Brief**: 300-500 tokens (50% of base)
   - **Balanced**: Base value (800 tokens default)
   - **Detailed**: Up to 1500 tokens (150% of base)
3. **Cut-Off Prevention**: System prompts include instructions to complete thoughts within limits

### Why This Matters

- **Mobile Optimization**: Brief responses stay concise for small screens
- **Complete Responses**: Appropriate limits prevent mid-sentence cut-offs
- **User Control**: Response length setting automatically manages complexity
- **Cost Efficiency**: Lower limits for brief responses reduce API costs

## Notes

- The app uses a single model (`OPENROUTER_MODEL`) for all chats
- All AI interactions use the same model configured in `.env`
- Free models may have rate limits
- Premium models may incur costs
- Token limits are automatically adjusted based on response length preferences
- System prompts include instructions to prevent cut-off responses

