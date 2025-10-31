# Traitus AI Chat

Modern, clean AI chat app powered by OpenRouter.

## Setup

1) Create a `.env` file at the project root:

```
OPENROUTER_API_KEY=sk-or-...
# Optional overrides
OPENROUTER_MODEL=openrouter/auto
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_SITE_URL=https://your-site.example
OPENROUTER_APP_NAME=Traitus AI Chat
```

2) Install dependencies:

```
flutter pub get
```

3) Run the app:

```
flutter run
```

## Notes

- Uses OpenAI-compatible `POST /chat/completions` on OpenRouter.
- Markdown rendering for assistant replies.
- Material 3 theming with light/dark support.
