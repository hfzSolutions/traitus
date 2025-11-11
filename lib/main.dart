import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:traitus/models/app_version_info.dart';
import 'package:traitus/providers/auth_provider.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/providers/notes_provider.dart';
import 'package:traitus/providers/theme_provider.dart';
import 'package:traitus/services/notification_service.dart';
import 'package:traitus/services/supabase_service.dart';
import 'package:traitus/services/version_control_service.dart';
import 'package:traitus/ui/auth_page.dart';
import 'package:traitus/ui/home_page.dart';
import 'package:traitus/ui/onboarding_page.dart';
import 'package:traitus/ui/update_required_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Supabase
  await SupabaseService.getInstance();
  
  // Initialize OneSignal notifications
  await NotificationService.initialize();
  
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

class _AuthCheckPageState extends State<AuthCheckPage> {
  VersionCheckStatus? _versionStatus;
  bool _isCheckingVersion = true;
  bool _hasShownOptionalUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    setState(() => _isCheckingVersion = true);
    
    try {
      final status = await VersionControlService().checkVersion();
      
      if (mounted) {
        setState(() {
          _versionStatus = status;
          _isCheckingVersion = false;
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
          _isCheckingVersion = false;
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
    // Still checking version
    if (_isCheckingVersion) {
      return const _LoadingScreen(message: 'Checking for updates...');
    }

    // Handle version check results
    if (_versionStatus != null) {
      // Force update or maintenance mode - block the app
      if (_versionStatus!.needsUpdate || _versionStatus!.inMaintenance) {
        return UpdateRequiredPage(
          status: _versionStatus!,
          onCheckAgain: _checkVersion,
        );
      }
    }

    // Version check passed, proceed with normal auth flow
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading screen while initializing (fetching user profile)
        if (authProvider.isInitializing) {
          return const _LoadingScreen();
        }
        
        // Not authenticated - show auth page
        if (!authProvider.isAuthenticated) {
          return const AuthPage();
        }
        
        // Check if user needs to complete onboarding
        if (authProvider.needsOnboarding) {
          return const OnboardingPage();
        }
        
        // All good - show home page
        return const HomePage();
      },
    );
  }
}

/// Loading/Splash screen shown while checking auth state
class _LoadingScreen extends StatelessWidget {
  final String? message;
  
  const _LoadingScreen({this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Spacer to push logo to center
              const Spacer(flex: 1),
              // App logo (transparent version for splash screen) - centered
              Image.asset(
                'assets/logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              // Spacer to push text to bottom
              const Spacer(flex: 1),
              // App name at the bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Traitus',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
