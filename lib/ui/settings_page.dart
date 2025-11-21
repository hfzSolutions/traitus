import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:traitus/providers/auth_provider.dart';
import 'package:traitus/providers/theme_provider.dart';
import 'package:traitus/ui/onboarding_page.dart';
import 'package:traitus/ui/pro_upgrade_page.dart';
import 'package:traitus/main.dart';
import 'package:traitus/ui/widgets/haptic_modal.dart';
import 'package:traitus/services/entitlements_service.dart' show EntitlementsService, UserPlan;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.isInTabView = false});
  
  final bool isInTabView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: !isInTabView,
      ),
      body: ListView(
        children: [
          // Appearance Section
          _SectionHeader(title: 'Appearance'),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Column(
                children: [
                  _ThemeOptionTile(
                    title: 'Light Mode',
                    subtitle: 'Always use light theme',
                    icon: Icons.light_mode,
                    isSelected: themeProvider.themeMode == ThemeMode.light,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                  ),
                  _ThemeOptionTile(
                    title: 'Dark Mode',
                    subtitle: 'Always use dark theme',
                    icon: Icons.dark_mode,
                    isSelected: themeProvider.themeMode == ThemeMode.dark,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                  ),
                  _ThemeOptionTile(
                    title: 'System Default',
                    subtitle: 'Follow system theme settings',
                    icon: Icons.brightness_auto,
                    isSelected: themeProvider.themeMode == ThemeMode.system,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          
          // Subscription Section
          _SectionHeader(title: 'Subscription'),
          FutureBuilder<UserPlan>(
            future: EntitlementsService().getCurrentUserPlan(),
            builder: (context, snapshot) {
              final plan = snapshot.data ?? UserPlan.free;
              final isPro = plan == UserPlan.pro;
              
              return ListTile(
                leading: Icon(
                  isPro ? Icons.workspace_premium : Icons.account_circle,
                  color: isPro 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                title: Text(
                  isPro ? 'Pro Plan' : 'Free Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isPro 
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                subtitle: Text(
                  isPro 
                      ? 'You have access to all premium models'
                      : 'Upgrade to unlock premium models',
                ),
                trailing: isPro
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                onTap: isPro
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProUpgradePage(),
                          ),
                        );
                      },
              );
            },
          ),
          const Divider(),
          
          // About Section
          _SectionHeader(title: 'About'),
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: theme.colorScheme.primary,
            ),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: Icon(
              Icons.code,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Traitus'),
            subtitle: const Text('Powered by OpenRouter API'),
          ),
          const Divider(),
          
          // Account Section
          _SectionHeader(title: 'Account'),
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.refresh,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Redo Onboarding'),
                    subtitle: const Text('Start the setup flow again'),
                    onTap: () => _showRedoOnboardingDialog(context, authProvider),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.logout,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Logout',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text('Sign out of your account'),
                    onTap: () => _showLogoutDialog(context, authProvider),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Delete Account',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text('Permanently delete your account and all data'),
                    onTap: () => _showDeleteAccountDialog(context, authProvider),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Future<void> _showLogoutDialog(BuildContext context, AuthProvider authProvider) async {
    final confirmed = await HapticModal.showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authProvider.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthCheckPage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _showRedoOnboardingDialog(BuildContext context, AuthProvider authProvider) async {
    final confirmed = await HapticModal.showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redo Onboarding'),
        content: const Text('This will take you back to the onboarding flow. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authProvider.redoOnboarding();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, AuthProvider authProvider) async {
    // First confirmation dialog
    final firstConfirmed = await HapticModal.showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.\n\n'
          'All your data will be permanently deleted, including:\n'
          '• Your chats and messages\n'
          '• Your notes\n'
          '• Your profile information\n'
          '• Your subscription data',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (firstConfirmed != true || !context.mounted) return;

    // Second confirmation dialog with type-to-confirm
    final secondConfirmed = await HapticModal.showDialog<bool>(
      context: context,
      builder: (context) => _DeleteAccountConfirmationDialog(),
    );

    if (secondConfirmed != true || !context.mounted) return;

    // Show loading dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await authProvider.deleteAccount();
      
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      // Show success message and navigate to auth
      if (context.mounted) {
        await HapticModal.showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Account Deleted'),
            content: const Text('Your account has been permanently deleted.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthCheckPage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      // Show error message
      if (context.mounted) {
        await HapticModal.showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to delete account: ${e.toString()}'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DeleteAccountConfirmationDialog extends StatefulWidget {
  @override
  State<_DeleteAccountConfirmationDialog> createState() => _DeleteAccountConfirmationDialogState();
}

class _DeleteAccountConfirmationDialogState extends State<_DeleteAccountConfirmationDialog> {
  final TextEditingController _confirmController = TextEditingController();
  final String _confirmText = 'DELETE';

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfirmed = _confirmController.text.trim().toUpperCase() == _confirmText;

    return AlertDialog(
      title: const Text('Final Confirmation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This action is permanent and cannot be undone. To confirm, please type DELETE in the box below:',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmController,
            decoration: InputDecoration(
              hintText: 'Type DELETE to confirm',
              border: const OutlineInputBorder(),
              errorText: _confirmController.text.isNotEmpty && !isConfirmed
                  ? 'Text does not match'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isConfirmed
              ? () => Navigator.pop(context, true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: const Text('Delete Account'),
        ),
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected 
            ? theme.colorScheme.primary 
            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
            )
          : null,
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
    );
  }
}

