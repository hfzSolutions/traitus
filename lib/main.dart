import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:traitus/app_initializer.dart';
import 'package:traitus/models/app_version_info.dart';
import 'package:traitus/providers/auth_provider.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/providers/notes_provider.dart';
import 'package:traitus/providers/theme_provider.dart';
import 'package:traitus/services/activity_service.dart';
import 'package:traitus/services/supabase_service.dart';
import 'package:traitus/services/version_control_service.dart';
import 'package:traitus/ui/auth_page.dart';
import 'package:traitus/ui/home_page.dart';
import 'package:traitus/ui/onboarding_page.dart';
import 'package:traitus/ui/update_required_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wait for critical initialization (env + Supabase) before showing UI
  // This is fast and necessary for the app to work
  await AppInitializer.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(SupabaseService.instance),
        ),
        ChangeNotifierProvider(create: (_) => ChatsListProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Traitus',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0167DE),
                brightness: Brightness.light,
              ).copyWith(
                primary: const Color(0xFF0167DE),
                onPrimary: Colors.white,
                primaryContainer: const Color(0xFFE6F0FF), // light blue bubble
                onPrimaryContainer: const Color(0xFF0B2F63),
              ),
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0167DE),
                brightness: Brightness.dark,
              ).copyWith(
                primary: const Color(0xFF0167DE),
                onPrimary: Colors.white,
                primaryContainer: const Color(0xFF163B6E), // darker container for dark mode
                onPrimaryContainer: Colors.white,
              ),
              brightness: Brightness.dark,
            ),
            themeMode: themeProvider.themeMode,
            home: const AuthCheckPage(),
          );
        },
      ),
    );
  }
}

class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> with WidgetsBindingObserver {
  VersionCheckStatus? _versionStatus;
  bool _hasShownOptionalUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkVersion();
    // Track initial app open
    _updateActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Track when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _updateActivity();
    }
  }

  Future<void> _updateActivity() async {
    try {
      await ActivityService().updateLastActivity();
    } catch (e) {
      debugPrint('Error updating activity: $e');
      // Don't block app if activity tracking fails
    }
  }

  Future<void> _checkVersion() async {
    try {
      final status = await VersionControlService().checkVersion();
      
      if (mounted) {
        setState(() {
          _versionStatus = status;
        });

        // Show optional update dialog if needed (only once per session)
        if (status.hasOptionalUpdate && !_hasShownOptionalUpdate) {
          _hasShownOptionalUpdate = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOptionalUpdateDialog();
          });
        }
      }
    } catch (e) {
      debugPrint('Version check error: $e');
      // On error, allow app to proceed
      if (mounted) {
        setState(() {
          _versionStatus = VersionCheckStatus(
            result: VersionCheckResult.upToDate,
          );
        });
      }
    }
  }

  Future<void> _showOptionalUpdateDialog() async {
    if (_versionStatus == null || !_versionStatus!.hasOptionalUpdate) return;

    final result = await UpdateAvailableDialog.show(
      context,
      _versionStatus!,
    );

    // If user clicked update and opened store, recheck version
    if (result == true && mounted) {
      _checkVersion();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isInitializing) {
          if (!authProvider.isAuthenticated) {
            return const AuthPage();
          }

          if (authProvider.needsOnboarding) {
            return const OnboardingPage();
          }

          return const HomePage();
        }

        if (!authProvider.isAuthenticated) {
          return const AuthPage();
        }

        if (authProvider.needsOnboarding) {
          return const OnboardingPage();
        }

        return const HomePage();
      },
    );

    final shouldBlockForUpdate = _versionStatus != null &&
        (_versionStatus!.needsUpdate || _versionStatus!.inMaintenance);

    return Stack(
      children: [
        content,
        if (shouldBlockForUpdate)
          Positioned.fill(
            child: UpdateRequiredPage(
              status: _versionStatus!,
              onCheckAgain: _checkVersion,
            ),
          ),
      ],
    );
  }
}


