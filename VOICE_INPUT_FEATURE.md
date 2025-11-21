# Voice Input Feature

## Overview

The voice input feature allows users to speak their messages instead of typing them. The app uses the device's built-in speech recognition to convert speech to text in real-time. The feature includes an advanced hold-to-talk mode with real-time waveform visualization that responds to voice input.

## Features

- 🎤 **Voice-to-Text Conversion**: Speak your message and it will be transcribed automatically
- ⚡ **Real-Time Transcription**: See your words appear in the text field as you speak
- ✏️ **Editable**: You can edit the transcribed text before sending
- 🔴 **Visual Feedback**: Button turns red with pulsing animation while recording
- 📊 **Real-Time Waveform Visualization**: Animated bars that respond to your voice in real-time (like Waze/Siri)
- 🎯 **Hold-to-Talk Mode**: Press and hold to record, release to automatically send
- 🔄 **Continuous Use**: Hold-to-talk mode stays active for multiple messages
- 👁️ **Smart Visibility**: Mic button hides when you start typing
- ⌨️ **Keyboard Icon**: Easy return to text input with keyboard icon
- 🛡️ **Abuse Protection**: Prevents rapid clicking and app hangs
- ⏱️ **Sensitivity Control**: 100ms delay prevents accidental triggers
- 🌐 **Free**: Uses device's built-in speech recognition (no API costs)

## How to Use

### Standard Voice Input Mode

1. **Start Recording**:
   - Tap the voice icon (speaking/voice icon) next to the plus button in the chat input bar
   - The button will turn red to indicate recording is active
   - The text field will show "Listening..." hint

2. **Speak Your Message**:
   - Speak clearly into your device's microphone
   - You'll see your words appear in real-time in the text field
   - Partial results appear as you speak, final results are added when you pause

3. **Stop Recording**:
   - Tap the voice button again to stop
   - Or wait for automatic stop (3 seconds of silence or 60 seconds total)

4. **Edit and Send**:
   - Review and edit the transcribed text if needed
   - Tap the send button to send your message

### Hold-to-Talk Mode

1. **Switch to Hold-to-Talk**:
   - Tap the voice icon (speaking/voice icon) to switch to hold-to-talk mode
   - The input field will transform into a large "Hold to talk" button

2. **Record Your Message**:
   - **Press and hold** the "Hold to talk" button (requires 100ms hold to start)
   - The button will immediately turn red when you press down
   - Watch the **real-time waveform bars** animate as you speak
   - The text changes to "Release to send" while recording
   - Your words will appear in real-time in the text field

3. **Send Automatically**:
   - **Release the button** to automatically send your message
   - The message is sent immediately after release (no need to tap send)
   - The hold-to-talk view stays open for your next message

4. **Return to Text Input**:
   - Tap the **keyboard icon** (⌨️) on the right side of the hold-to-talk button
   - This returns you to standard text input mode and focuses the text field

### Visual Feedback

- **Button State**: 
  - Normal: Gray background with voice icon
  - Recording: Red background with animated waveform bars
  - Text: "Hold to talk" when idle, "Release to send" when recording

- **Waveform Visualization**:
  - 5 animated bars that respond to your voice in real-time
  - Bars rise and fall with your speech rhythm
  - Each bar responds to different frequency ranges for natural variation
  - Smooth animations that follow voice input (like Waze/Siri)

- **Pulsing Animation**:
  - Red pulsing circle behind the button when recording
  - Provides clear visual feedback that recording is active

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

#### 1. Speech Recognition Initialization
```dart
final stt.SpeechToText _speech = stt.SpeechToText();
bool _isAvailable = false;
bool _isHoldToTalkMode = false; // Toggle between text and hold-to-talk mode
bool _isListening = false; // Current recording state
bool _isStarting = false; // Prevent multiple simultaneous starts
```

#### 2. State Management
- `_isListening`: Tracks if currently recording
- `_isHoldToTalkMode`: Tracks if hold-to-talk mode is active
- `_isStarting`: Prevents overlapping start operations
- `_baseText`: Stores confirmed transcribed text
- `_partialText`: Stores temporary partial results
- `_isUpdatingFromSpeech`: Prevents conflicts between speech updates and manual edits
- `_soundLevel`: Current audio level (0.0 to 1.0) for waveform visualization
- `_pointerDownTime`: Tracks when pointer was pressed for sensitivity control
- `_hasStartedFromPointer`: Tracks if recording started from current pointer press

#### 3. Real-Time Sound Level Detection
```dart
onSoundLevelChange: (level) {
  // Sound level is in dB, typically -160 (silence) to 0 (max)
  // Normalize to 0.0 - 1.0 range with exponential curve
  final normalized = ((level + 160) / 160).clamp(0.0, 1.0);
  _soundLevel = (normalized * normalized * 1.3).clamp(0.0, 1.0);
}
```

#### 4. Waveform Visualization Widget
- **Widget**: `_SoundWaveform`
- **Bars**: 5 animated bars that respond to sound level
- **Frequency Variation**: Each bar responds to different frequency ranges (0.6x to 1.4x multiplier)
- **Smooth Animation**: Uses `AnimatedContainer` with 100ms duration for smooth transitions
- **Real-Time Updates**: Updates continuously to follow voice rhythm

#### 5. Hold-to-Talk Button Implementation

**Dual Event Handling**:
- **Listener**: Primary handler for reliable pointer events
  - `onPointerDown`: Starts recording after 100ms delay (prevents accidental triggers)
  - `onPointerUp`: Stops recording immediately
  - `onPointerCancel`: Stops recording if gesture is cancelled
- **GestureDetector**: Backup handler for tap events
  - Same delay logic as Listener
  - Only triggers if Listener didn't already handle it

**Sensitivity Control**:
- 100ms delay before starting recording
- Requires deliberate press (not accidental touch)
- If user releases before 100ms, recording doesn't start

**Immediate State Updates**:
- State is updated synchronously before async operations
- UI updates immediately when user releases (red button turns off instantly)
- Speech recognition stop happens asynchronously in background

#### 6. Abuse Protection Mechanisms

**Debouncing**:
- 500ms minimum interval between starts
- Prevents rapid clicking

**Operation Tracking**:
- `_currentStartOperation`: Tracks current async start operation
- Prevents overlapping operations
- Subsequent calls wait for current operation to complete

**Timeouts**:
- 5-second timeout for start operations
- 2-second timeout for stop operations
- Prevents app from hanging

**State Validation**:
- Multiple checks before starting/stopping
- Proper cleanup in all error paths
- Flags reset to prevent stuck states

#### 7. Icon Changes
- **Voice Icon**: Changed from `Icons.mic_none` to `Icons.record_voice_over` (speaking/voice icon)
- **Back Button**: Changed from `Icons.arrow_back` to `Icons.keyboard` (keyboard icon)
- **Text**: "Hold to talk" when idle, "Release to send" when recording

### Configuration

The speech recognition is configured with:
- **Listen Duration**: 60 seconds maximum (for hold-to-talk)
- **Pause Duration**: 3 seconds of silence before auto-stop
- **Locale**: `en_US` (English - United States)
- **Partial Results**: Enabled for real-time feedback
- **Error Handling**: Automatic cancellation on errors
- **Sound Level Updates**: Real-time updates for waveform visualization

### Sound Level Normalization

The sound level is normalized using an exponential curve:
- **Input Range**: -160 dB (silence) to 0 dB (max)
- **Normalization**: `((level + 160) / 160)` to get 0.0-1.0 range
- **Curve**: `normalized² * 1.3` for better sensitivity
  - Makes quiet speech more visible
  - Prevents saturation on loud speech
  - Better responds to speech variations

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

## UI/UX Details

### Button Design

**Hold-to-Talk Button**:
- **Height**: 56px
- **Border Radius**: 28px (fully rounded)
- **Normal State**: 
  - Background: `surfaceContainerHighest`
  - Border: 1px outline with 0.2 opacity
  - Icon: Voice icon (record_voice_over)
  - Text: "Hold to talk"
- **Recording State**:
  - Background: `errorContainer` (red)
  - Border: 2px error color
  - Icon: Animated waveform bars
  - Text: "Release to send"
  - Pulsing circle animation behind button

**Back Button** (Keyboard Icon):
- Positioned on the right side of hold-to-talk button
- Only visible when not recording
- Circular button with keyboard icon
- Smooth slide-in animation from right

### Animations

- **Button State Transition**: Smooth color and border changes
- **Waveform Bars**: Real-time height changes with 100ms animation
- **Pulsing Circle**: Continuous pulse animation (1 second cycle)
- **Mode Switch**: Fade and scale transition (200ms)
- **Back Button**: Slide in from right with fade (200ms)

### User Experience Flow

1. User sees voice icon when input is empty
2. User starts typing → voice icon smoothly hides
3. User clears text → voice icon smoothly reappears
4. User taps voice icon → switches to hold-to-talk mode
5. User presses button → button turns red immediately
6. After 100ms → recording starts, waveform appears
7. User speaks → waveform bars animate with voice, text appears in real-time
8. User releases → button turns off immediately, message sends automatically
9. Hold-to-talk stays active → user can immediately record again
10. User taps keyboard icon → returns to text input mode, text field focused

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

### Button Stays Red After Release
- **Cause**: Rare edge case with event handling
- **Solution**: Fixed with immediate state updates and dual event handling (Listener + GestureDetector)

### App Hangs on Rapid Clicking
- **Cause**: Multiple overlapping async operations
- **Solution**: Fixed with operation tracking, debouncing, and timeouts

## Privacy Considerations

- Speech recognition uses device's native services
- Audio may be processed on-device or in the cloud (depending on platform)
- No audio data is stored by the app
- Users should review platform privacy policies (Apple/Google)

## Performance Optimizations

1. **Immediate State Updates**: UI updates synchronously before async operations
2. **Operation Tracking**: Prevents overlapping async operations
3. **Debouncing**: Reduces unnecessary operations from rapid clicks
4. **Timeouts**: Prevents hanging operations
5. **State Validation**: Multiple checks prevent invalid states
6. **Smooth Animations**: 100ms duration for responsive but smooth transitions

## Future Enhancements

Potential improvements:
- Language selection (currently hardcoded to `en_US`)
- Offline mode support detection
- Customizable sensitivity delay
- Multiple language support
- Voice activity detection (auto-start/stop)
- Noise cancellation feedback
- Waveform bar count customization
- Animation speed customization

## Related Files

- `lib/ui/chat_page.dart` - Main implementation
  - `_InputBarState` class - Main voice input logic
  - `_SoundWaveform` widget - Waveform visualization
  - `_PulsingCircle` widget - Pulsing animation
  - `_buildHoldToTalkButton` method - Hold-to-talk button UI
- `pubspec.yaml` - Package dependency (`speech_to_text: ^7.0.0`)
- `android/app/src/main/AndroidManifest.xml` - Android permissions
- `ios/Runner/Info.plist` - iOS permissions

## Implementation Details

### Waveform Visualization Algorithm

The waveform uses a sophisticated algorithm to create natural-looking bars:

1. **Sound Level Input**: Receives dB level from speech recognition (-160 to 0)
2. **Normalization**: Converts to 0.0-1.0 range with exponential curve
3. **Frequency Variation**: Each of 5 bars uses different multiplier (0.6x to 1.4x)
4. **Smooth Animation**: `AnimatedContainer` with 100ms duration
5. **Real-Time Updates**: Updates on every sound level change

### Event Handling Architecture

```
User Action
    ↓
Listener (Primary)
    ↓
100ms Delay Check
    ↓
Start Recording (if still pressed)
    ↓
GestureDetector (Backup)
    ↓
Same Logic (if Listener didn't handle)
```

### State Machine

```
IDLE → PRESSING (100ms delay) → RECORDING → RELEASED → SENDING → IDLE
  ↑                                                              ↓
  └────────────────────────────────────────────────────────────┘
                    (if cancelled or error)
```

## Testing Checklist

- [x] Hold-to-talk starts after 100ms press
- [x] Quick tap (< 100ms) doesn't start recording
- [x] Button turns red immediately on press
- [x] Waveform appears when recording starts
- [x] Waveform bars respond to voice in real-time
- [x] Button turns off immediately on release
- [x] Message sends automatically on release
- [x] Rapid clicking doesn't cause hangs
- [x] Keyboard icon returns to text input
- [x] Text field focuses when returning to text mode
- [x] Multiple messages work in hold-to-talk mode
- [x] Error handling resets state properly
- [x] Timeouts prevent hanging operations
