import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseAuthService {
  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isConfigured => SupabaseConfig.isConfigured && _client != null;

  Session? get currentSession => _client?.auth.currentSession;
  User? get currentUser => _client?.auth.currentUser;

  Stream<AuthState> get onAuthStateChange {
    final client = _client;
    if (client == null) return const Stream.empty();
    return client.auth.onAuthStateChange;
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured. Please check project URL and publishable key.');
    }
    return await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SupabaseConfig.authCallbackUrl,
      data: fullName != null && fullName.trim().isNotEmpty
          ? {'full_name': fullName.trim()}
          : null,
    );
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured. Please check project URL and publishable key.');
    }
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> resendConfirmationEmail(String email) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured. Please check project URL and publishable key.');
    }
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: SupabaseConfig.authCallbackUrl,
    );
  }

  Future<bool> signInWithGoogle() async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured. Please check project URL and publishable key.');
    }
    try {
      final success = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : SupabaseConfig.authCallbackUrl,
      );
      return success;
    } catch (e) {
      debugPrint('Google OAuth initiation error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    final client = _client;
    if (client != null) {
      await client.auth.signOut();
    }
  }
}
