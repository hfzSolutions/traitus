import 'package:flutter/material.dart';
import 'package:traitus/models/app_version_info.dart';
import 'package:traitus/services/version_control_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page shown when app update is required or in maintenance mode
class UpdateRequiredPage extends StatelessWidget {
  final VersionCheckStatus status;
  final VoidCallback? onCheckAgain;

  const UpdateRequiredPage({
    super.key,
    required this.status,
    this.onCheckAgain,
  });

  @override
  Widget build(BuildContext context) {
    if (status.inMaintenance) {
      return _MaintenanceScreen(
        status: status,
        onCheckAgain: onCheckAgain,
      );
    }

    return _UpdateScreen(
      status: status,
      isRequired: status.needsUpdate,
      onCheckAgain: onCheckAgain,
    );
  }
}

/// Screen shown during maintenance mode
class _MaintenanceScreen extends StatelessWidget {
  final VersionCheckStatus status;
  final VoidCallback? onCheckAgain;

  const _MaintenanceScreen({
    required this.status,
    this.onCheckAgain,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Maintenance icon
                Icon(
                  Icons.construction,
                  size: 100,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Under Maintenance',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Message
                Text(
                  status.message ?? 'App is currently under maintenance. Please check back later.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Retry button
                FilledButton.icon(
                  onPressed: () {
                    // Clear cache and trigger recheck via callback
                    VersionControlService().clearCache();
                    if (onCheckAgain != null) {
                      onCheckAgain!();
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen shown when update is available or required
class _UpdateScreen extends StatelessWidget {
  final VersionCheckStatus status;
  final bool isRequired;
  final VoidCallback? onCheckAgain;

  const _UpdateScreen({
    required this.status,
    required this.isRequired,
    this.onCheckAgain,
  });

  Future<void> _openStore(BuildContext context) async {
    final versionInfo = status.versionInfo;
    if (versionInfo == null) return;

    final storeUrl = VersionControlService().getStoreUrl(versionInfo);
    if (storeUrl == null || storeUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store URL not available'),
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open store'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versionInfo = status.versionInfo;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Update icon
                Icon(
                  isRequired ? Icons.system_update_alt : Icons.update,
                  size: 100,
                  color: isRequired ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  versionInfo?.updateTitle ?? 'Update Available',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Message
                Text(
                  status.message ?? 
                  (isRequired 
                    ? 'A required update is available. Please update to continue using the app.'
                    : 'A new version is available with improvements and bug fixes.'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Version info
                if (versionInfo != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Latest Version:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              '${versionInfo.latestVersion} (${versionInfo.latestBuildNumber})',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (isRequired) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Minimum Version:',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              Text(
                                '${versionInfo.minimumVersion} (${versionInfo.minimumBuildNumber})',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Update button
                FilledButton.icon(
                  onPressed: () => _openStore(context),
                  icon: const Icon(Icons.download),
                  label: Text(isRequired ? 'Update Now' : 'Update'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isRequired 
                      ? theme.colorScheme.error 
                      : theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                
                // Skip button (only for optional updates)
                if (!isRequired) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Maybe Later'),
                  ),
                ],
                
                // Retry check button
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    VersionControlService().clearCache();
                    if (onCheckAgain != null) {
                      onCheckAgain!();
                    } else {
                      Navigator.of(context).pop(true); // Signal to recheck
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Check Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog to show optional update prompt
class UpdateAvailableDialog extends StatelessWidget {
  final VersionCheckStatus status;

  const UpdateAvailableDialog({
    super.key,
    required this.status,
  });

  static Future<bool?> show(BuildContext context, VersionCheckStatus status) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => UpdateAvailableDialog(status: status),
    );
  }

  Future<void> _openStore(BuildContext context) async {
    final versionInfo = status.versionInfo;
    if (versionInfo == null) return;

    final storeUrl = VersionControlService().getStoreUrl(versionInfo);
    if (storeUrl == null || storeUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store URL not available'),
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open store'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versionInfo = status.versionInfo;

    return AlertDialog(
      icon: Icon(
        Icons.update,
        size: 48,
        color: theme.colorScheme.primary,
      ),
      title: Text(versionInfo?.updateTitle ?? 'Update Available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.message ?? 
            'A new version is available with improvements and bug fixes.',
            textAlign: TextAlign.center,
          ),
          if (versionInfo != null) ...[
            const SizedBox(height: 16),
            Text(
              'Latest Version: ${versionInfo.latestVersion} (${versionInfo.latestBuildNumber})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () async {
            // Open store directly
            await _openStore(context);
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

