# Voice Reply Feature

## Overview

The voice reply feature allows users to listen to AI responses as spoken audio. When an AI assistant sends a text response, users can tap a play button to hear the message read aloud using text-to-speech (TTS) technology.

## Features

- 🔊 **Text-to-Speech Conversion**: Convert AI text responses to natural-sounding voice
- ⏯️ **Play/Pause Control**: Start and stop voice playback with a single tap
- 🎨 **Visual Feedback**: Button icon changes to indicate playback state
- 🧹 **Smart Text Cleaning**: Automatically removes markdown formatting for better TTS quality
- 🛑 **Auto-Stop**: Automatically stops when navigating away or app goes to background
- 🌐 **Cross-Platform**: Works on iOS, Android, Web, macOS, Windows, Linux
- 💰 **Free**: Uses device's built-in TTS engine (no API costs)

## How to Use

1. **Wait for AI Response**: Let the AI finish generating its response
2. **Tap Play Button**: Look for the speaker icon (🔊) on any AI message bubble
3. **Listen**: The message will be read aloud in a natural voice
4. **Stop**: Tap the pause icon (⏸️) to stop playback at any time

## Technical Implementation

### Package Used

- **Package**: `flutter_tts` (version ^4.0.2)
- **Platform Support**: iOS, Android, Web, macOS, Windows, Linux

### Architecture

The feature consists of two main components:

1. **TTS Service** (`lib/services/tts_service.dart`)
   - Singleton service managing TTS functionality
   - Handles initialization, playback control, and state management
   - Cleans markdown formatting from text before speaking
   - Tracks which message is currently playing

2. **UI Integration** (`lib/ui/chat_page.dart`)
   - Play/pause button in assistant message bubbles
   - State management for button appearance
   - Auto-stop on navigation and app lifecycle changes

### Key Components

#### TTS Service

```dart
class TtsService extends ChangeNotifier {
  // Singleton instance
  static final TtsService _instance = TtsService._internal();
  
  // Availability tracking
  bool _isAvailable = false;
  bool _isPlaying = false;
  String? _currentMessageId;
  
  // Initialize TTS engine
  Future<void> initialize()
  
  // Speak text for a message
  Future<bool> speak(String text, String messageId)
  
  // Stop playback
  Future<void> stop()
  
  // Check if specific message is playing
  bool isPlayingMessage(String messageId)
}
```

#### Message Bubble Integration

- Play button appears only for completed assistant messages
- Button shows play icon (🔊) when not playing
- Button shows pause icon (⏸️) when playing
- Button highlights in primary color when active
- Button is hidden if TTS is not available

### Text Cleaning

Before speaking, the TTS service automatically cleans the text:

- Removes markdown code blocks (replaced with "[code block]")
- Removes inline code (replaced with "[code]")
- Removes markdown links (keeps link text)
- Removes markdown headers, bold, italic formatting
- Removes list markers
- Normalizes whitespace

This ensures natural-sounding speech without technical formatting artifacts.

### State Management

- Uses `ChangeNotifier` pattern for reactive updates
- UI automatically updates when playback state changes
- Only one message can play at a time (stops previous if new one starts)
- State persists across message bubble rebuilds

### Auto-Stop Behavior

TTS automatically stops in these scenarios:

1. **Navigation Away**: When user navigates away from chat screen
2. **App Background**: When app goes to background or becomes inactive
3. **New Message**: When user starts playing a different message
4. **Playback Complete**: When speech finishes naturally

## Platform-Specific Notes

### iOS
- Uses AVSpeechSynthesizer
- Requires iOS 10.0 or later
- Works on physical devices
- **Note**: May not work on iOS Simulator (this is expected behavior)

### Android
- Uses Android's TextToSpeech engine
- Works on physical devices and emulators
- Supports multiple languages and voices

### Web
- Uses browser's Web Speech API
- Requires HTTPS connection (except localhost)
- Browser compatibility varies

### macOS/Windows/Linux
- Uses platform-native TTS engines
- Full support for desktop platforms

## Configuration

### Default Settings

- **Language**: English (en-US)
- **Speech Rate**: 0.5 (moderate speed)
- **Volume**: 1.0 (maximum)
- **Pitch**: 1.0 (normal)

### Customization Options

The TTS service provides methods for customization (not exposed in UI yet):

```dart
// Set speech rate (0.0 to 1.0)
await ttsService.setSpeechRate(0.7);

// Set volume (0.0 to 1.0)
await ttsService.setVolume(0.8);

// Set pitch (0.5 to 2.0)
await ttsService.setPitch(1.2);

// Set language
await ttsService.setLanguage("en-GB");
```

## Troubleshooting

### Play Button Not Appearing

**Cause**: TTS is not available on the device
**Solutions**:
- This is normal on iOS Simulator - TTS requires a physical device
- Check device compatibility
- Ensure TTS engine is properly initialized

### No Sound Playing

**Possible Causes**:
1. Device volume is muted
2. TTS engine not available (common on simulators)
3. Text is empty after cleaning

**Solutions**:
- Check device volume settings
- Test on a physical device instead of simulator
- Ensure message has text content

### Playback Stops Unexpectedly

**Possible Causes**:
1. App went to background
2. User navigated away from chat
3. Another message started playing
4. TTS engine error

**Solutions**:
- This is expected behavior - TTS stops when leaving screen
- Check console for error messages
- Restart playback if needed

### Simulator Issues

**Note**: TTS may not work on iOS Simulator. This is expected behavior:
- iOS Simulator doesn't fully support TTS
- The feature will work on physical iOS devices
- Android emulators typically work fine

## Privacy Considerations

- TTS processing happens on-device
- No audio data is sent to external servers
- Text content is processed locally
- No data is stored or logged

## Future Enhancements

Potential improvements:
- Speech rate adjustment slider
- Voice selection (male/female, different accents)
- Language selection per message
- Auto-play option for new messages
- Progress indicator during playback
- Skip forward/backward controls
- Background playback support (optional)

## Code Locations

### Main Files

- `lib/services/tts_service.dart` - TTS service implementation
- `lib/ui/chat_page.dart` - UI integration and button placement
- `pubspec.yaml` - Package dependency (`flutter_tts: ^4.0.2`)

### Key Methods

**TTS Service**:
- `initialize()` - Initialize TTS engine
- `speak(text, messageId)` - Start speaking
- `stop()` - Stop playback
- `isPlayingMessage(messageId)` - Check playback state

**Chat Page**:
- `_toggleTts()` - Handle play/pause button tap
- `_checkTtsState()` - Update button appearance
- `didChangeAppLifecycleState()` - Handle app backgrounding
- `dispose()` - Stop TTS on navigation

## Related Features

- **Voice Input**: See `VOICE_INPUT_FEATURE.md` for speech-to-text functionality
- **Streaming Responses**: Works seamlessly with streaming AI responses
- **Message Actions**: Complements copy, save, and regenerate actions

## Testing

### Recommended Test Scenarios

1. **Basic Playback**
   - Start playback on a completed message
   - Verify sound plays correctly
   - Stop playback mid-sentence

2. **Navigation**
   - Start playback
   - Navigate away from chat
   - Verify playback stops automatically

3. **App Lifecycle**
   - Start playback
   - Put app in background
   - Verify playback stops

4. **Multiple Messages**
   - Start playback on message A
   - Start playback on message B
   - Verify message A stops and message B plays

5. **Long Messages**
   - Test with very long AI responses
   - Verify playback handles long text correctly

### Test Devices

- ✅ Physical iOS device (recommended)
- ✅ Physical Android device
- ✅ Android emulator
- ⚠️ iOS Simulator (may not work - expected)

## Summary

The voice reply feature provides a convenient way for users to listen to AI responses, making the app more accessible and user-friendly. It uses device-native TTS engines for high-quality, offline-capable voice synthesis with no additional API costs.

