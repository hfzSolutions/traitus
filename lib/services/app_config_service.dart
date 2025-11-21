import 'package:flutter/foundation.dart';
import 'package:traitus/services/database_service.dart';

/// Service for managing app configuration from database
/// All model configurations must be stored in the app_config table
class AppConfigService {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();

  final DatabaseService _dbService = DatabaseService();
  Map<String, String>? _cachedConfig;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);
  bool _isInitializing = false;
  Future<void>? _initializationFuture;

  /// Initialize the config cache (call this early in app startup)
  Future<void> initialize() async {
    if (_isInitializing) {
      return _initializationFuture ?? Future.value();
    }
    
    // CRITICAL FIX: Check if cache is empty, not just if it exists
    final cacheIsEmpty = _cachedConfig == null || _cachedConfig!.isEmpty;
    final cacheIsFresh = _cachedConfig != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
    
    if (!cacheIsEmpty && cacheIsFresh) {
      return; // Already cached and fresh
    }
    
    _isInitializing = true;
    _initializationFuture = _refreshCache();
    await _initializationFuture;
    _isInitializing = false;
  }

  /// Refresh the cache from database
  Future<void> _refreshCache() async {
    try {
      _cachedConfig = await _dbService.fetchAllAppConfig();
      _cacheTimestamp = DateTime.now();
      
      if (_cachedConfig == null || _cachedConfig!.isEmpty) {
        debugPrint('[AppConfigService] Warning: Fetched empty config from database');
      }
    } catch (e) {
      debugPrint('[AppConfigService] Error refreshing app config cache: $e');
      rethrow;
    }
  }

  /// Get default model for chats
  /// Must be set in app_config table with key 'default_model'
  Future<String> getDefaultModel() async {
    // CRITICAL FIX: If cache is empty, force refresh even if timestamp is fresh
    // This handles the case where cache was initialized before user login (empty result)
    final cacheIsEmpty = _cachedConfig == null || _cachedConfig!.isEmpty;
    final cacheIsStale = _cacheTimestamp == null || 
        DateTime.now().difference(_cacheTimestamp!) >= _cacheDuration;
    
    if (cacheIsEmpty || cacheIsStale) {
      await _refreshCache();
    }
    
    final dbModel = _cachedConfig?['default_model'];
    if (dbModel == null || dbModel.isEmpty) {
      throw StateError('Missing default_model in app_config table. Please set it in the database.');
    }
    return dbModel;
  }

  /// Get model for onboarding/assistant finding
  /// Falls back to default_model if not set
  Future<String> getOnboardingModel() async {
    final dbModel = await _getConfig('onboarding_model');
    if (dbModel != null && dbModel.isNotEmpty) {
      return dbModel;
    }
    
    // Fallback to default model
    return await getDefaultModel();
  }

  /// Get model for quick reply generation
  /// Falls back to default_model if not set
  Future<String> getQuickReplyModel() async {
    final dbModel = await _getConfig('quick_reply_model');
    if (dbModel != null && dbModel.isNotEmpty) {
      return dbModel;
    }
    
    // Fallback to default model
    return await getDefaultModel();
  }

  /// Get a configuration value by key
  /// Uses cache if available and fresh, otherwise fetches from database
  Future<String?> _getConfig(String key) async {
    // Ensure cache is initialized
    if (_cachedConfig == null || 
        _cacheTimestamp == null || 
        DateTime.now().difference(_cacheTimestamp!) >= _cacheDuration) {
      await _refreshCache();
    }
    
    return _cachedConfig?[key];
  }

  /// Invalidate the cache (call this when config is updated)
  void invalidateCache() {
    _cachedConfig = null;
    _cacheTimestamp = null;
  }

  /// Get a configuration value synchronously (from cache only)
  /// Returns null if not cached or cache is stale
  /// Throws error if default_model is not available
  String? getCachedConfig(String key) {
    if (_cachedConfig != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedConfig![key];
    }
    return null;
  }
  
  /// Get default model synchronously (from cache only)
  /// Returns cached value if available, otherwise throws error
  /// Note: Call initialize() first to ensure cache is loaded
  String getCachedDefaultModel() {
    final cached = getCachedConfig('default_model');
    if (cached == null || cached.isEmpty) {
      throw StateError('Default model not available in cache. Call AppConfigService.instance.initialize() first, or ensure default_model is set in app_config table.');
    }
    return cached;
  }
  
  /// Get default model synchronously with fallback to async fetch
  /// This is safer - will fetch from DB if cache not available
  Future<String> getDefaultModelSafe() async {
    final cached = getCachedConfig('default_model');
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    // Cache not available, fetch from database
    return await getDefaultModel();
  }
}

