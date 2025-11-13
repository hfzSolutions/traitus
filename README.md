# Traitus AI Chat

Modern, cloud-powered AI chat application with user authentication and persistent storage.

## ✨ Features

- 🔐 **User Authentication** - Secure sign up, sign in, and password reset
- ☁️ **Cloud Storage** - All data stored in Supabase (no local storage)
- 💬 **AI Chat** - Multiple chat conversations with customizable AI assistants
- 🤖 **Model Selection** - Choose different AI models for each chat
- ⚡ **Streaming Responses** - Real-time word-by-word AI responses (like ChatGPT)
- 🖼️ **Custom Avatars** - Personalize your AI chats with custom avatar images
- 📝 **Notes** - Save and manage your notes
- ⚡ **Instant Loading** - Message preloading for instant chat opening (like WhatsApp/Telegram)
- 🔔 **Push Notifications** - Get notified of new messages (powered by OneSignal)
- 🎨 **Modern UI** - Material 3 design with light/dark theme support
- 📱 **Cross-platform** - Works on iOS, Android, Web, macOS, Windows, and Linux

## 🚀 Quick Start

### 1. Prerequisites

- Flutter SDK (3.9.2 or higher)
- A Supabase account ([sign up here](https://supabase.com))
- An OpenRouter API key ([get one here](https://openrouter.ai))

### 2. Set Up Supabase

Follow the detailed instructions in [SUPABASE_SETUP.md](SUPABASE_SETUP.md):

1. Create a Supabase project
2. Run the SQL migrations in order:
   - `supabase_migration_restore_model_selection.sql` (creates models table)
   - `supabase_migration_add_app_config_models.sql` (creates app_config table)
   - `supabase_migration_validate_app_config_models.sql` (adds validation)
   - `supabase_migration_add_rls_app_config_models.sql` (adds RLS)
   - Other migrations as needed (see SUPABASE_SETUP.md)
3. Get your Supabase URL and anon key

### 3. Configure Environment Variables

Create a `.env` file in the project root:

```env
# OpenRouter API Key (for AI chat)
OPENROUTER_API_KEY=your_openrouter_api_key_here

# Supabase Configuration
SUPABASE_URL=https://xxxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

**Note:** Model configuration is now stored in the database. See [MODEL_SELECTION_AND_CONFIG.md](MODEL_SELECTION_AND_CONFIG.md) for details.

**Important:** Never commit your `.env` file to version control!

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Run the App

```bash
flutter run
```

## 📱 Using the App

### First Time Users

1. Launch the app
2. Click **"Sign Up"** on the auth screen
3. Enter your email and password (min 6 characters)
4. Click **"Sign Up"**
5. Check your email for verification (depending on Supabase settings)
6. Sign in with your credentials

### Existing Users

1. Launch the app
2. Enter your email and password
3. Click **"Sign In"**
4. Start chatting!

### Features

- **Multiple Chats**: Create different chat conversations with custom AI personalities
- **Custom Avatars**: Upload custom images for your AI chat assistants (see [AVATAR_FEATURE.md](AVATAR_FEATURE.md))
- **Notes**: Save important information from your chats or create standalone notes
- **Settings**: Customize theme and manage your account
- **Sign Out**: Securely sign out from the settings page

## 🗄️ Database Schema

The app uses three main tables:

- **`chats`** - Stores chat conversations (name, description, system prompt, last message)
- **`messages`** - Stores individual messages within chats (role, content, model used, timestamps)
- **`models`** - Stores available AI models that users can select from
- **`app_config`** - Stores default model configurations (default_model, onboarding_model, quick_reply_model)
- **`notes`** - Stores user notes (title, content, timestamps)

All tables have Row Level Security (RLS) enabled, ensuring users can only access their own data.

## 🔒 Security

- ✅ Row Level Security (RLS) enabled on all tables
- ✅ User authentication required for all operations
- ✅ Data isolated by user ID
- ✅ Secure password handling via Supabase Auth
- ✅ PKCE authentication flow for mobile apps

## 🛠️ Tech Stack

- **Flutter** - Cross-platform UI framework
- **Supabase** - Backend as a Service (auth, database, real-time)
- **Provider** - State management
- **OpenRouter** - AI model access
- **Flutter Markdown** - Rich text rendering

## 📂 Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── ai_chat.dart
│   ├── chat_message.dart
│   ├── model.dart            # Model configuration from database
│   └── note.dart
├── providers/                # State management
│   ├── auth_provider.dart
│   ├── chat_provider.dart
│   ├── chats_list_provider.dart
│   ├── notes_provider.dart
│   └── theme_provider.dart
├── services/                 # Business logic
│   ├── supabase_service.dart
│   ├── database_service.dart
│   ├── storage_service.dart  # Avatar upload/management
│   ├── openrouter_api.dart
│   └── app_config_service.dart  # App configuration from database
└── ui/                       # User interface
    ├── auth_page.dart
    ├── chat_list_page.dart
    ├── chat_page.dart
    ├── notes_page.dart
    └── settings_page.dart
```

## 🔧 Configuration

### Model Selection and Configuration

The app supports **user-selectable models** with database-driven configuration. All model settings are stored in the database (no environment variables needed for models).

**Key Features:**
- ✅ Users can choose different models for each chat
- ✅ Models are managed in the `models` table
- ✅ Default models configured in `app_config` table
- ✅ Data integrity validation ensures config references valid models
- ✅ Row Level Security (RLS) protects configuration

**Setup:**
1. Run the model selection migrations (see [MODEL_SELECTION_AND_CONFIG.md](MODEL_SELECTION_AND_CONFIG.md))
2. Models are automatically loaded from the database
3. Users can select models when creating/editing chats

**Default Models:**
- `default_model`: Used for all chats (required)
- `onboarding_model`: Used for onboarding (optional, falls back to default)
- `quick_reply_model`: Used for quick replies (optional, falls back to default)

**Managing Models:**
- Add models via Supabase dashboard: Insert into `models` table
- Change default model: Update `app_config` table
- All model values must reference valid `model_id` from `models` table

For complete documentation, see [MODEL_SELECTION_AND_CONFIG.md](MODEL_SELECTION_AND_CONFIG.md)

### Supabase Settings

- **Email Confirmation**: Configure in Supabase Dashboard → Authentication → Settings
- **Email Templates**: Customize in Supabase Dashboard → Authentication → Email Templates
- **Password Requirements**: Configure in Supabase Dashboard → Authentication → Settings

## 🐛 Troubleshooting

### Authentication Issues

- Verify your Supabase credentials in `.env`
- Check if email confirmation is enabled in Supabase
- Look at app logs for detailed error messages

### Database Issues

- Ensure you ran the SQL schema in Supabase
- Check that RLS policies are correctly set up
- Verify you're using the correct Supabase URL and anon key

### Build Issues

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## 📚 Documentation

- [Model Selection and Configuration](MODEL_SELECTION_AND_CONFIG.md) - Complete guide to model selection and database-driven configuration
- [Supabase Setup Guide](SUPABASE_SETUP.md) - Detailed Supabase configuration
- [Avatar Feature Guide](AVATAR_FEATURE.md) - Custom AI avatar setup and usage
- [App Icon Setup Guide](APP_ICON_SETUP.md) - How to add and update app icons for all platforms
- [Database Schema](supabase_schema.sql) - SQL schema for Supabase
- [Realtime Subscription & Unread Tracking](REALTIME_SUBSCRIPTION.md) - Real-time message updates and unread indicators
- [Message Caching & UX Improvements](MESSAGE_CACHING_AND_UX.md) - Instant chat loading, message preloading, and standard chat behavior
- [Streaming Response Feature](STREAMING_RESPONSE_FEATURE.md) - Real-time word-by-word AI responses with streaming
- [Push Notifications Setup](PUSH_NOTIFICATIONS_SETUP.md) - OneSignal integration for push notifications
- [Flutter Documentation](https://docs.flutter.dev)
- [Supabase Documentation](https://supabase.com/docs)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Built with [Flutter](https://flutter.dev)
- Powered by [Supabase](https://supabase.com)
- AI via [OpenRouter](https://openrouter.ai)
