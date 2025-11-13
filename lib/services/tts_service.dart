import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service for text-to-speech functionality
/// Handles converting AI responses to voice output
class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isAvailable = false;
  String? _currentMessageId;
  bool _isPlaying = false;
  bool _isPaused = false;

  /// Getter for TTS availability
  bool get isAvailable => _isAvailable;
  
  /// Getter for current playing state
  bool get isPlaying => _isPlaying;
  
  /// Getter for current paused state
  bool get isPaused => _isPaused;
  
  /// Getter for current message ID being played
  String? get currentMessageId => _currentMessageId;

  /// Initialize TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Try to set default language to check if TTS is available
      await _flutterTts.setLanguage("en-US");
      
      // Set speech rate (0.0 to 1.0, default is 0.5)
      await _flutterTts.setSpeechRate(0.5);
      
      // Set volume (0.0 to 1.0, default is 1.0)
      await _flutterTts.setVolume(1.0);
      
      // Set pitch (0.5 to 2.0, default is 1.0)
      await _flutterTts.setPitch(1.0);

      // Set up completion handler
      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        _isPaused = false;
        _currentMessageId = null;
        notifyListeners();
      });

      // Set up error handler
      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _isPlaying = false;
        _isPaused = false;
        _currentMessageId = null;
        notifyListeners();
      });

      // Set up start handler
      _flutterTts.setStartHandler(() {
        _isPlaying = true;
        _isPaused = false;
        notifyListeners();
      });

      _isInitialized = true;
      _isAvailable = true;
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
      debugPrint('TTS is not available (this is normal on simulators)');
      _isInitialized = true; // Mark as initialized to avoid retrying
      _isAvailable = false;
    }
  }

  /// Speak the given text for a specific message
  /// Returns true if successful, false otherwise
  Future<bool> speak(String text, String messageId) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isAvailable) {
      debugPrint('TTS is not available');
      return false;
    }

    try {
      // Stop any currently playing speech
      await stop();

      // Clean text - remove markdown formatting for better TTS
      final cleanText = _cleanTextForTTS(text);

      if (cleanText.isEmpty) {
        return false;
      }

      _currentMessageId = messageId;
      await _flutterTts.speak(cleanText);
      _isPlaying = true;
      _isPaused = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error speaking text: $e');
      // If we get an error, mark as unavailable
      _isAvailable = false;
      _isPlaying = false;
      _isPaused = false;
      _currentMessageId = null;
      notifyListeners();
      return false;
    }
  }

  /// Pause current speech
  Future<void> pause() async {
    if (!_isInitialized || !_isPlaying) return;

    try {
      await _flutterTts.pause();
      _isPaused = true;
    } catch (e) {
      debugPrint('Error pausing TTS: $e');
    }
  }

  /// Resume paused speech
  Future<void> resume() async {
    if (!_isInitialized || !_isPaused) return;

    try {
      await _flutterTts.speak(""); // Resume by speaking empty string (platform-specific)
      // Note: flutter_tts doesn't have a direct resume method on all platforms
      // This is a workaround - on some platforms we may need to restart
      _isPaused = false;
    } catch (e) {
      debugPrint('Error resuming TTS: $e');
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.stop();
      _isPlaying = false;
      _isPaused = false;
      _currentMessageId = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  /// Check if a specific message is currently being played
  bool isPlayingMessage(String messageId) {
    return _isPlaying && _currentMessageId == messageId;
  }

  /// Clean text for TTS by removing markdown and special characters
  String _cleanTextForTTS(String text) {
    // Remove markdown code blocks
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '[code block]');
    
    // Remove inline code
    text = text.replaceAll(RegExp(r'`[^`]+`'), '[code]');
    
    // Remove markdown links but keep the text
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    
    // Remove markdown headers
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    
    // Remove markdown bold/italic
    text = text.replaceAll(RegExp(r'\*\*([^\*]+)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*([^\*]+)\*'), r'$1');
    text = text.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
    text = text.replaceAll(RegExp(r'_([^_]+)_'), r'$1');
    
    // Remove markdown lists
    text = text.replaceAll(RegExp(r'^[\*\-\+]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
    
    // Remove extra whitespace
    text = text.replaceAll(RegExp(r'\n\s*\n'), '. ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    
    return text.trim();
  }

  /// Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Set pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
  }

  /// Get available languages
  Future<List<dynamic>> getLanguages() async {
    if (!_isInitialized) await initialize();
    try {
      return await _flutterTts.getLanguages;
    } catch (e) {
      debugPrint('Error getting languages: $e');
      return [];
    }
  }

  /// Set language
  Future<void> setLanguage(String language) async {
    if (!_isInitialized) await initialize();
    try {
      await _flutterTts.setLanguage(language);
    } catch (e) {
      debugPrint('Error setting language: $e');
    }
  }
}

