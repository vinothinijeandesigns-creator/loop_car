import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  final _auth = SupabaseConfig.auth;
  final _client = SupabaseConfig.client;

  // ==================== SIGN UP ====================

  /// Sign up with email, password, and user metadata
  /// The profile is automatically created via database trigger
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String mobile,
    required String dob, // Format: 'YYYY-MM-DD'
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'mobile': mobile,
        'dob': dob,
      },
    );
    return response;
  }

  // ==================== SIGN IN ====================

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithPassword(email: email, password: password);
  }

  /// Sign in with Google OAuth
  Future<void> signInWithGoogle() async {
    await _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.loopcar://login-callback/',
    );
  }

  /// Sign in with Apple OAuth (iOS)
  Future<void> signInWithApple() async {
    await _auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.loopcar://login-callback/',
    );
  }

  // ==================== SIGN OUT ====================

  /// Sign out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ==================== PASSWORD RESET ====================

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.loopcar://reset-callback/',
    );
  }

  /// Update password (after reset)
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _auth.updateUser(UserAttributes(password: newPassword));
  }

  // ==================== PROFILE MANAGEMENT ====================

  /// Get the current user's profile from the profiles table
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final userId = SupabaseConfig.userId;
    if (userId == null) return null;

    final response =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();

    return response;
  }

  /// Update the current user's profile
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? mobile,
    String? avatarUrl,
    bool? isDriver,
    bool? commitmentAccepted,
  }) async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');

    final updates = <String, dynamic>{};

    if (firstName != null) updates['first_name'] = firstName;
    if (lastName != null) updates['last_name'] = lastName;
    if (mobile != null) updates['mobile'] = mobile;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (isDriver != null) updates['is_driver'] = isDriver;
    if (commitmentAccepted != null) {
      updates['commitment_accepted'] = commitmentAccepted;
    }

    if (updates.isNotEmpty) {
      // Try to update, if profile doesn't exist yet (trigger delay), wait and retry
      try {
        await _client.from('profiles').update(updates).eq('id', userId);
      } catch (e) {
        // Wait for trigger to create profile, then retry
        await Future.delayed(const Duration(seconds: 1));
        await _client.from('profiles').update(updates).eq('id', userId);
      }
    }
  }

  /// Deactivate the current user's account
  Future<void> deactivateAccount() async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');
    
    final result = await _client
        .from('profiles')
        .update({'status': 'inactive'})
        .eq('id', userId)
        .select();

    if (result.isEmpty) {
      throw Exception('Failed to update profile. Check RLS or user ID.');
    }
  }

  /// Accept the carpool commitment
  Future<void> acceptCommitment() async {
    final userId = SupabaseConfig.userId;
    if (userId == null) {
      // User just signed up, skip saving - will be handled on next login
      return;
    }

    try {
      await updateProfile(commitmentAccepted: true);
    } catch (e) {
      // If profile update fails, just proceed - not critical for first signup
      debugPrint('Could not update commitment: $e');
    }
  }

  // ==================== AUTH STATE ====================

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Check if the current session is valid
  Future<bool> isSessionValid() async {
    final session = SupabaseConfig.currentSession;
    if (session == null) return false;

    // Check if token is expired
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;

    final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    return DateTime.now().isBefore(expiryDate);
  }

  /// Refresh the current session
  Future<AuthResponse> refreshSession() async {
    return await _auth.refreshSession();
  }

  /// Resend confirmation email
  Future<void> resendConfirmationEmail(String email) async {
    await _auth.resend(type: OtpType.signup, email: email);
  }
}
