# Voice Input Feature

## Overview

The voice input feature allows users to speak their messages instead of typing them. The app uses the device's built-in speech recognition to convert speech to text in real-time.

## Features

- 🎤 **Voice-to-Text Conversion**: Speak your message and it will be transcribed automatically
- ⚡ **Real-Time Transcription**: See your words appear in the text field as you speak
- ✏️ **Editable**: You can edit the transcribed text before sending
- 🔴 **Visual Feedback**: Microphone button turns red while recording
- ⏱️ **Auto-Stop**: Automatically stops after 30 seconds or 3 seconds of silence
- 🌐 **Free**: Uses device's built-in speech recognition (no API costs)

## How to Use

1. **Start Recording**:
   - Tap the microphone icon (🎤) in the chat input bar
   - The button will turn red to indicate recording is active
   - The text field will show "Listening..." hint

2. **Speak Your Message**:
   - Speak clearly into your device's microphone
   - You'll see your words appear in real-time in the text field
   - Partial results appear as you speak, final results are added when you pause

3. **Stop Recording**:
   - Tap the microphone button again to stop
   - Or wait for automatic stop (3 seconds of silence or 30 seconds total)

4. **Edit and Send**:
   - Review and edit the transcribed text if needed
   - Tap the send button to send your message

## Technical Implementation

### Package Used

- **Package**: `speech_to_text` (version ^7.0.0)
- **Platform Support**: iOS, Android, Web, macOS, Windows, Linux

### Permissions Required

#### Android
- `RECORD_AUDIO` - Required for microphone access
- Added to `android/app/src/main/AndroidManifest.xml`

#### iOS
- `NSMicrophoneUsageDescription` - Required for microphone access
- `NSSpeechRecognitionUsageDescription` - Required for speech recognition
- Added to `ios/Runner/Info.plist`

### Code Location

The voice input functionality is implemented in:
- **File**: `lib/ui/chat_page.dart`
- **Widget**: `_InputBarState` class

### Key Components

1. **Speech Recognition Initialization**:
   ```dart
   final stt.SpeechToText _speech = stt.SpeechToText();
   bool _isAvailable = false;
   ```

2. **Listening State Management**:
   - `_isListening`: Tracks if currently recording
   - `_baseText`: Stores confirmed transcribed text
   - `_partialText`: Stores temporary partial results
   - `_isUpdatingFromSpeech`: Prevents conflicts between speech updates and manual edits

3. **Real-Time Updates**:
   - Partial results update the text field in real-time
   - Final results are appended to the base text
   - Users can manually edit text while listening

### Configuration

The speech recognition is configured with:
- **Listen Duration**: 30 seconds maximum
- **Pause Duration**: 3 seconds of silence before auto-stop
- **Locale**: `en_US` (English - United States)
- **Partial Results**: Enabled for real-time feedback
- **Error Handling**: Automatic cancellation on errors

## Platform-Specific Notes

### iOS
- Uses Apple's Speech Recognition framework
- Works on-device or cloud-based depending on device capabilities
- Requires iOS 10.0 or later

### Android
- Uses Google's Speech Recognition service
- Requires internet connection for cloud-based recognition
- Some devices support offline recognition

### Web
- Uses browser's Web Speech API
- Requires HTTPS connection (except localhost)
- Browser compatibility varies

## Troubleshooting

### Microphone Button Not Appearing
- **Cause**: Speech recognition not available on device
- **Solution**: Check device compatibility and permissions

### Permission Denied
- **Cause**: User denied microphone permission
- **Solution**: Go to device settings and enable microphone permission for the app

### No Transcription
- **Cause**: Poor audio quality, background noise, or network issues
- **Solution**: 
  - Speak clearly and reduce background noise
  - Check internet connection (for cloud-based recognition)
  - Ensure microphone is not blocked

### Text Not Updating
- **Cause**: Speech recognition service unavailable
- **Solution**: Check device settings and ensure speech recognition is enabled

## Privacy Considerations

- Speech recognition uses device's native services
- Audio may be processed on-device or in the cloud (depending on platform)
- No audio data is stored by the app
- Users should review platform privacy policies (Apple/Google)

## Future Enhancements

Potential improvements:
- Language selection (currently hardcoded to `en_US`)
- Offline mode support detection
- Voice commands for sending messages
- Audio waveform visualization during recording
- Multiple language support

## Related Files

- `lib/ui/chat_page.dart` - Main implementation
- `pubspec.yaml` - Package dependency
- `android/app/src/main/AndroidManifest.xml` - Android permissions
- `ios/Runner/Info.plist` - iOS permissions

