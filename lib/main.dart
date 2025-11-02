import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:traitus/providers/auth_provider.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/providers/notes_provider.dart';
import 'package:traitus/providers/theme_provider.dart';
import 'package:traitus/services/supabase_service.dart';
import 'package:traitus/ui/auth_page.dart';
import 'package:traitus/ui/home_page.dart';
import 'package:traitus/ui/onboarding_page.dart';

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

class AuthCheckPage extends StatelessWidget {
  const AuthCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
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
  const _LoadingScreen();

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
          ],
        ),
      ),
    );
  }
}
