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

## Optional Variables - AI Model Configuration

These variables control which AI models are used for the default AI assistants during onboarding. If not set, the application will use sensible defaults.

### General Model Settings

```bash
# Free model (used for most assistants if no specific override is set)
DEFAULT_MODEL_FREE=minimax/minimax-m2:free

# Premium model (used for productivity and learning assistants)
DEFAULT_MODEL_PREMIUM=minimax/minimax-m2:free

# General fallback model (used if nothing else is specified)
DEFAULT_MODEL=minimax/minimax-m2:free
```

### Individual Assistant Model Overrides

You can override the model for each specific assistant type:

```bash
# Coding Assistant
DEFAULT_MODEL_CODING=minimax/minimax-m2:free

# Creative Writer
DEFAULT_MODEL_CREATIVE=minimax/minimax-m2:free

# Research Assistant
DEFAULT_MODEL_RESEARCH=minimax/minimax-m2:free

# Productivity Coach
DEFAULT_MODEL_PRODUCTIVITY=minimax/minimax-m2:free

# Learning Tutor
DEFAULT_MODEL_LEARNING=minimax/minimax-m2:free

# Business Advisor
DEFAULT_MODEL_BUSINESS=minimax/minimax-m2:free
```

## Model Selection Logic

The system selects models in the following priority order:

1. **Specific Override**: `DEFAULT_MODEL_<TYPE>` (e.g., `DEFAULT_MODEL_CODING`)
2. **Category Default**: 
   - `DEFAULT_MODEL_FREE` for: coding, creative, research, business
   - `DEFAULT_MODEL_PREMIUM` for: productivity, learning
3. **Global Fallback**: `DEFAULT_MODEL`
4. **Hardcoded Fallback**: `minimax/minimax-m2:free`

## Example Configurations

### Development (Free Models)
```bash
DEFAULT_MODEL_FREE=minimax/minimax-m2:free
DEFAULT_MODEL_PREMIUM=minimax/minimax-m2:free
```

### Production (Mixed Models)
```bash
DEFAULT_MODEL_FREE=minimax/minimax-m2:free
DEFAULT_MODEL_PREMIUM=minimax/minimax-m2:free
DEFAULT_MODEL_CODING=anthropic/claude-3.5-sonnet
DEFAULT_MODEL_RESEARCH=anthropic/claude-3.5-sonnet
```

### All Premium Models
```bash
DEFAULT_MODEL_FREE=anthropic/claude-3.5-sonnet
DEFAULT_MODEL_PREMIUM=minimax/minimax-m2:free
```

## Available Models (OpenRouter)

Here are some popular models you can use:

### Free Models
- `minimax/minimax-m2:free` - Fast and free
- `google/gemini-2.0-flash-exp:free` - Google's Gemini
- `meta-llama/llama-3.1-8b-instruct:free` - Meta's Llama

### Premium Models
- `minimax/minimax-m2:free` - OpenAI's GPT-4 Omni
- `anthropic/claude-3.5-sonnet` - Anthropic's Claude
- `google/gemini-pro-1.5` - Google's Gemini Pro
- `meta-llama/llama-3.1-70b-instruct` - Larger Llama model

For a full list of available models, visit: https://openrouter.ai/models

## Setup Instructions

1. Copy your `.env` file (or create one)
2. Add the required Supabase and OpenRouter credentials
3. (Optional) Add model configuration variables
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

- Model changes only affect **new** AI chats created during onboarding
- Existing chats keep their original model
- Users can change the model for any chat after creation
- Free models may have rate limits
- Premium models may incur costs
- Token limits are automatically adjusted based on response length preferences
- System prompts include instructions to prevent cut-off responses

