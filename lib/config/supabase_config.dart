import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // TODO: Replace with your Supabase project credentials
  // Get these from: Supabase Dashboard → Project Settings → API
  static const String supabaseUrl =
      'https://usysfcfncfiwdqpqzije.supabase.co'; // e.g., https://xxxxx.supabase.co
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeXNmY2ZuY2Zpd2RxcHF6aWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MDc2OTMsImV4cCI6MjA4NDk4MzY5M30.XafXkazhRb9wDqJZSNb27z9G3WRRboHmZatDIMFrRDs';

  /// Initialize Supabase - call this in main() before runApp()
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
  }

  /// Get the Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;

  /// Get the auth instance
  static GoTrueClient get auth => client.auth;

  /// Get the current authenticated user
  static User? get currentUser => auth.currentUser;

  /// Get the current user's ID
  static String? get userId => currentUser?.id;

  /// Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  /// Get the current session
  static Session? get currentSession => auth.currentSession;
}
