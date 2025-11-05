import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:traitus/models/app_version_info.dart';
import 'package:traitus/services/supabase_service.dart';

/// Service to check app version and handle force updates
class VersionControlService {
  static final VersionControlService _instance = VersionControlService._internal();
  factory VersionControlService() => _instance;
  VersionControlService._internal();
  
  PackageInfo? _packageInfo;
  AppVersionInfo? _cachedVersionInfo;
  DateTime? _lastCheckTime;
  
  // Cache version check for 5 minutes to avoid excessive API calls
  static const _cacheDuration = Duration(minutes: 5);

  /// Get current app version information
  Future<PackageInfo> getPackageInfo() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  /// Get current platform string
  String getCurrentPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'all';
  }

  /// Fetch version info from database for current platform
  Future<AppVersionInfo?> fetchVersionInfo({bool forceRefresh = false}) async {
    // Return cached version if available and fresh
    if (!forceRefresh && 
        _cachedVersionInfo != null && 
        _lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _cacheDuration) {
      return _cachedVersionInfo;
    }

    try {
      final platform = getCurrentPlatform();
      
      // Try to get platform-specific version first, fallback to 'all'
      final response = await SupabaseService.client
          .from('app_version_control')
          .select()
          .inFilter('platform', [platform, 'all'])
          .order('platform', ascending: false) // Platform-specific takes precedence
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _cachedVersionInfo = AppVersionInfo.fromJson(response);
        _lastCheckTime = DateTime.now();
        return _cachedVersionInfo;
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching version info: $e');
      return null;
    }
  }

  /// Check if current app version meets requirements
  Future<VersionCheckStatus> checkVersion() async {
    try {
      final packageInfo = await getPackageInfo();
      final versionInfo = await fetchVersionInfo();

      if (versionInfo == null) {
        // If we can't fetch version info, allow the app to proceed
        return VersionCheckStatus(
          result: VersionCheckResult.upToDate,
          message: 'Unable to check version',
        );
      }

      // Check maintenance mode first
      if (versionInfo.maintenanceMode) {
        return VersionCheckStatus(
          result: VersionCheckResult.maintenanceMode,
          versionInfo: versionInfo,
          message: versionInfo.maintenanceMessage,
        );
      }

      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // Check if force update is required
      if (versionInfo.forceUpdate) {
        final needsUpdate = _compareVersions(
          currentVersion,
          currentBuildNumber,
          versionInfo.minimumVersion,
          versionInfo.minimumBuildNumber,
        ) < 0;

        if (needsUpdate) {
          return VersionCheckStatus(
            result: VersionCheckResult.updateRequired,
            versionInfo: versionInfo,
            message: versionInfo.updateMessage ?? 
                     'A required update is available. Please update to continue using the app.',
          );
        }
      }

      // Check if optional update is available
      if (versionInfo.showUpdatePrompt) {
        final hasUpdate = _compareVersions(
          currentVersion,
          currentBuildNumber,
          versionInfo.latestVersion,
          versionInfo.latestBuildNumber,
        ) < 0;

        if (hasUpdate) {
          return VersionCheckStatus(
            result: VersionCheckResult.updateAvailable,
            versionInfo: versionInfo,
            message: versionInfo.updateMessage ?? 
                     'A new version is available with improvements and bug fixes.',
          );
        }
      }

      // App is up to date
      return VersionCheckStatus(
        result: VersionCheckResult.upToDate,
        versionInfo: versionInfo,
      );
    } catch (e) {
      debugPrint('Error checking version: $e');
      // On error, allow the app to proceed
      return VersionCheckStatus(
        result: VersionCheckResult.upToDate,
        message: 'Unable to check version',
      );
    }
  }

  /// Compare two versions
  /// Returns: -1 if current < required, 0 if equal, 1 if current > required
  int _compareVersions(
    String currentVersion,
    int currentBuild,
    String requiredVersion,
    int requiredBuild,
  ) {
    // First compare build numbers (more specific)
    if (currentBuild < requiredBuild) return -1;
    if (currentBuild > requiredBuild) return 1;

    // If build numbers are equal, compare semantic versions
    final current = _parseVersion(currentVersion);
    final required = _parseVersion(requiredVersion);

    for (int i = 0; i < 3; i++) {
      if (current[i] < required[i]) return -1;
      if (current[i] > required[i]) return 1;
    }

    return 0; // Versions are equal
  }

  /// Parse semantic version string (e.g., "1.2.3") into list of integers
  List<int> _parseVersion(String version) {
    final parts = version.split('.');
    return [
      int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0,
    ];
  }

  /// Get appropriate store URL for current platform
  String? getStoreUrl(AppVersionInfo versionInfo) {
    if (kIsWeb) return versionInfo.webAppUrl;
    if (Platform.isIOS) return versionInfo.iosAppStoreUrl;
    if (Platform.isAndroid) return versionInfo.androidPlayStoreUrl;
    return null;
  }

  /// Clear cached version info
  void clearCache() {
    _cachedVersionInfo = null;
    _lastCheckTime = null;
  }
}

