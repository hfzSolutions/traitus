# Voice Input Feature

## Overview

The voice input feature allows users to speak their messages instead of typing them. The app uses the device's built-in speech recognition to convert speech to text in real-time.

## Features

- 🎤 **Voice-to-Text Conversion**: Speak your message and it will be transcribed automatically
- ⚡ **Real-Time Transcription**: See your words appear in the text field as you speak
- ✏️ **Editable**: You can edit the transcribed text before sending
- 🔴 **Visual Feedback**: Microphone button turns red while recording
- 🎯 **Hold-to-Talk Mode**: Long-press to record, release to automatically send
- 🔄 **Continuous Use**: Hold-to-talk mode stays active for multiple messages
- 👁️ **Smart Visibility**: Mic button hides when you start typing
- 🌐 **Free**: Uses device's built-in speech recognition (no API costs)

## How to Use

### Standard Voice Input Mode

1. **Start Recording**:
   - Tap the microphone icon (🎤) next to the plus button in the chat input bar
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

### Hold-to-Talk Mode

1. **Switch to Hold-to-Talk**:
   - Tap the microphone icon (🎤) to switch to hold-to-talk mode
   - The input field will transform into a large "Hold to talk" button

2. **Record Your Message**:
   - Long-press and hold the "Hold to talk" button
   - Speak your message while holding
   - The button will show "Recording..." with a pulsing animation
   - Your words will appear in real-time

3. **Send Automatically**:
   - Release the button to automatically send your message
   - The message is sent immediately after release (no need to tap send)
   - The hold-to-talk view stays open for your next message

4. **Return to Text Input**:
   - Tap the back arrow button (→) on the right side of the hold-to-talk button
   - This returns you to standard text input mode

### Smart Button Behavior

- **Mic Button Visibility**: The mic button automatically hides when you start typing text
- **Button Position**: Located on the right side of the input field, next to the plus/send button
- **Smooth Animations**: All transitions use standard Material Design animations

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
   bool _isHoldToTalkMode = false; // Toggle between text and hold-to-talk mode
   ```

2. **Listening State Management**:
   - `_isListening`: Tracks if currently recording
   - `_isHoldToTalkMode`: Tracks if hold-to-talk mode is active
   - `_baseText`: Stores confirmed transcribed text
   - `_partialText`: Stores temporary partial results
   - `_isUpdatingFromSpeech`: Prevents conflicts between speech updates and manual edits

3. **Real-Time Updates**:
   - Partial results update the text field in real-time
   - Final results are appended to the base text
   - Users can manually edit text while listening

4. **Hold-to-Talk Implementation**:
   - Uses `GestureDetector` with `onLongPressStart` and `onLongPressEnd`
   - Automatically sends message on button release
   - Keeps hold-to-talk mode active for continuous use
   - Back button positioned on the right side for easy access

5. **Smart Button Visibility**:
   - Mic button uses `AnimatedSwitcher` for smooth transitions
   - Hides when user starts typing (`hasText` is true)
   - Shows when text field is empty and speech is available

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

## UI/UX Details

### Button Positioning
- **Mic Button**: Located on the right side of the input field, next to the plus/send button
- **Styling**: Matches the plus button theme (circular, same background color, same border)
- **Spacing**: 2px gap between mic and plus/send buttons for compact layout

### Animations
- **Mic Button Hide/Show**: Fade and scale animation (200ms duration)
- **Hold-to-Talk Transition**: Smooth fade and scale transition when switching modes
- **Back Button**: Slides in from the right with fade animation

### User Experience Flow
1. User sees mic button when input is empty
2. User starts typing → mic button smoothly hides
3. User clears text → mic button smoothly reappears
4. User taps mic → switches to hold-to-talk mode
5. User holds button → records and sees real-time transcription
6. User releases → message automatically sends
7. Hold-to-talk stays active → user can immediately record again
8. User taps back arrow → returns to text input mode

## Future Enhancements

Potential improvements:
- Language selection (currently hardcoded to `en_US`)
- Offline mode support detection
- Audio waveform visualization during recording
- Multiple language support
- Voice activity detection (auto-start/stop)
- Noise cancellation feedback

## Related Files

- `lib/ui/chat_page.dart` - Main implementation
- `pubspec.yaml` - Package dependency
- `android/app/src/main/AndroidManifest.xml` - Android permissions
- `ios/Runner/Info.plist` - iOS permissions

