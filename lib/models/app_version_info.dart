/// Model for app version control information from database
class AppVersionInfo {
  final String id;
  final String platform;
  final String minimumVersion;
  final int minimumBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final bool forceUpdate;
  final bool showUpdatePrompt;
  final String? updateMessage;
  final String? updateTitle;
  final String? iosAppStoreUrl;
  final String? androidPlayStoreUrl;
  final String? webAppUrl;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppVersionInfo({
    required this.id,
    required this.platform,
    required this.minimumVersion,
    required this.minimumBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.forceUpdate,
    required this.showUpdatePrompt,
    this.updateMessage,
    this.updateTitle,
    this.iosAppStoreUrl,
    this.androidPlayStoreUrl,
    this.webAppUrl,
    required this.maintenanceMode,
    this.maintenanceMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      id: json['id'] as String,
      platform: json['platform'] as String,
      minimumVersion: json['minimum_version'] as String,
      minimumBuildNumber: json['minimum_build_number'] as int,
      latestVersion: json['latest_version'] as String,
      latestBuildNumber: json['latest_build_number'] as int,
      forceUpdate: json['force_update'] as bool? ?? false,
      showUpdatePrompt: json['show_update_prompt'] as bool? ?? true,
      updateMessage: json['update_message'] as String?,
      updateTitle: json['update_title'] as String?,
      iosAppStoreUrl: json['ios_app_store_url'] as String?,
      androidPlayStoreUrl: json['android_play_store_url'] as String?,
      webAppUrl: json['web_app_url'] as String?,
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      maintenanceMessage: json['maintenance_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platform': platform,
      'minimum_version': minimumVersion,
      'minimum_build_number': minimumBuildNumber,
      'latest_version': latestVersion,
      'latest_build_number': latestBuildNumber,
      'force_update': forceUpdate,
      'show_update_prompt': showUpdatePrompt,
      'update_message': updateMessage,
      'update_title': updateTitle,
      'ios_app_store_url': iosAppStoreUrl,
      'android_play_store_url': androidPlayStoreUrl,
      'web_app_url': webAppUrl,
      'maintenance_mode': maintenanceMode,
      'maintenance_message': maintenanceMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Result of version check
enum VersionCheckResult {
  /// App is up to date
  upToDate,
  
  /// Update available but optional
  updateAvailable,
  
  /// Update is required (force update)
  updateRequired,
  
  /// App is in maintenance mode
  maintenanceMode,
}

/// Status information after version check
class VersionCheckStatus {
  final VersionCheckResult result;
  final AppVersionInfo? versionInfo;
  final String? message;

  VersionCheckStatus({
    required this.result,
    this.versionInfo,
    this.message,
  });

  bool get needsUpdate => result == VersionCheckResult.updateRequired;
  bool get hasOptionalUpdate => result == VersionCheckResult.updateAvailable;
  bool get inMaintenance => result == VersionCheckResult.maintenanceMode;
  bool get canProceed => result == VersionCheckResult.upToDate || 
                         result == VersionCheckResult.updateAvailable;
}

