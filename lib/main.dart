import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:traitus/models/app_version_info.dart';
import 'package:traitus/providers/auth_provider.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/providers/notes_provider.dart';
import 'package:traitus/providers/theme_provider.dart';
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
            title: 'Traitus AI Chat',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or icon
            Icon(
              Icons.chat_bubble,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Traitus AI',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
