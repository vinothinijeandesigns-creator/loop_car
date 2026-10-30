import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/supabase_config.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/update_password_screen.dart';
import 'services/communication_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  runApp(const LoopCarApp());
}

class LoopCarApp extends StatefulWidget {
  const LoopCarApp({super.key});

  @override
  State<LoopCarApp> createState() => _LoopCarAppState();
}

class _LoopCarAppState extends State<LoopCarApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Listen for auth state changes
    SupabaseConfig.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      if (session != null) {
        // Special case: If user came from a password reset link
        if (data.event == AuthChangeEvent.passwordRecovery) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UpdatePasswordScreen()),
            (route) => false,
          );
          return;
        }

        // Fetch profile to see if active
        final userId = session.user.id;
        try {
          final profile =
              await SupabaseConfig.client
                  .from('profiles')
                  .select('status')
                  .eq('id', userId)
                  .maybeSingle();

          if (profile != null && profile['status'] == 'inactive') {
            await SupabaseConfig.auth.signOut();
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder:
                    (_) => const LoginScreen(
                      initialErrorMessage: 'This account has been deactivated.',
                    ),
              ),
              (route) => false,
            );
            return;
          }
        } catch (e) {
          debugPrint('Error checking profile status: $e');
        }

        // Initialize Push Notifications
        await CommunicationService.initializePushNotifications();

        // User is logged in and active, navigate to main shell
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      } else {
        // User is logged out, navigate to login page
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'LoopCar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00C6D2),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C6D2)),
        useMaterial3: true,
      ),
      // Initial screen based on current session
      home: SupabaseConfig.isLoggedIn ? const MainShell() : const LoginScreen(),
    );
  }
}
