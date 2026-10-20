import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/supabase_auth_service.dart';
import '../core/network/api_client.dart';

enum SignUpResultStatus {
  needsEmailConfirmation,
  alreadyRegistered,
  signedIn,
  failed,
}

class SignUpResult {
  final SignUpResultStatus status;
  final String email;
  final String? message;
  final bool success;

  const SignUpResult({
    required this.status,
    required this.email,
    this.message,
    required this.success,
  });
}

class AuthProvider extends ChangeNotifier {
  final SupabaseAuthService _authService;
  StreamSubscription<AuthState>? _authSubscription;

  User? _user;
  Session? _session;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  AuthProvider({SupabaseAuthService? authService})
      : _authService = authService ?? SupabaseAuthService() {
    _init();
  }

  void _init() {
    if (_authService.isConfigured) {
      _session = _authService.currentSession;
      _user = _authService.currentUser;
      ApiClient.authToken = _session?.accessToken;

      _authSubscription = _authService.onAuthStateChange.listen((data) {
        final event = data.event;
        _session = data.session;
        _user = data.session?.user;
        ApiClient.authToken = data.session?.accessToken;

        if (event == AuthChangeEvent.signedIn && _session != null) {
          _infoMessage = 'Email verified successfully! You are now signed in.';
          _errorMessage = null;
        } else if (event == AuthChangeEvent.signedOut) {
          ApiClient.authToken = null;
          _infoMessage = null;
        }

        notifyListeners();
      });
    }
  }

  bool get isConfigured => _authService.isConfigured;

  /// True ONLY when a confirmed user has an active session.
  /// Unconfirmed email accounts without a session never evaluate to authenticated.
  bool get isAuthenticated =>
      _session != null &&
      _user != null &&
      (_user!.emailConfirmedAt != null || _isOAuthUser);

  bool get _isOAuthUser {
    if (_user == null) return false;
    final provider = _user!.appMetadata['provider'];
    if (provider != null && provider != 'email') return true;
    final identities = _user!.identities;
    if (identities != null && identities.any((i) => i.provider != 'email')) return true;
    return false;
  }

  User? get user => _user;
  Session? get session => _session;
  String? get accessToken => _session?.accessToken;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  String get displayName {
    if (_user == null) return 'Guest';
    final metadata = _user!.userMetadata;
    if (metadata != null && metadata['full_name'] != null && (metadata['full_name'] as String).trim().isNotEmpty) {
      return metadata['full_name'] as String;
    }
    return _user!.email?.split('@').first ?? 'User';
  }

  String? get email => _user?.email;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearInfo() {
    _infoMessage = null;
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final res = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      _user = res.user;
      _session = res.session;
      ApiClient.authToken = res.session?.accessToken;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<SignUpResult> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final res = await _authService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );

      _isLoading = false;

      // Case 1: Session immediately established (e.g. autoconfirm enabled)
      if (res.session != null && res.user != null) {
        _user = res.user;
        _session = res.session;
        ApiClient.authToken = res.session?.accessToken;
        _infoMessage = 'Signed in successfully!';
        notifyListeners();
        return SignUpResult(
          status: SignUpResultStatus.signedIn,
          email: email,
          message: 'Signed in successfully!',
          success: true,
        );
      }

      // Case 2: Duplicate email / existing user (Supabase returns empty identities list)
      if (res.user != null && res.user!.identities != null && res.user!.identities!.isEmpty) {
        _user = null;
        _session = null;
        ApiClient.authToken = null;
        notifyListeners();
        return SignUpResult(
          status: SignUpResultStatus.alreadyRegistered,
          email: email,
          message: 'An account with this email already exists. Please sign in or check your email.',
          success: true,
        );
      }

      // Case 3: Email confirmation required (session is null)
      _user = null;
      _session = null;
      ApiClient.authToken = null;
      notifyListeners();

      return SignUpResult(
        status: SignUpResultStatus.needsEmailConfirmation,
        email: email,
        message: 'Check your email to verify your account.',
        success: true,
      );
    } on AuthException catch (e) {
      _errorMessage = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return SignUpResult(
        status: SignUpResultStatus.failed,
        email: email,
        message: _errorMessage,
        success: false,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return SignUpResult(
        status: SignUpResultStatus.failed,
        email: email,
        message: _errorMessage,
        success: false,
      );
    }
  }

  Future<bool> resendConfirmationEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _authService.resendConfirmationEmail(email);
      _infoMessage = 'Confirmation email resent to $email. Please check your inbox.';
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final success = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return success;
    } on AuthException catch (e) {
      _errorMessage = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('Sign-out notice: $e');
    } finally {
      _user = null;
      _session = null;
      ApiClient.authToken = null;
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}
      _infoMessage = null;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  String _formatAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    final code = e.code?.toLowerCase() ?? '';
    final status = e.statusCode?.toString() ?? '';

    if (msg.contains('email not confirmed') || code == 'email_not_confirmed') {
      return 'Email not verified. Please check your inbox for the confirmation link or resend it below.';
    }
    if (msg.contains('invalid login credentials') || code == 'invalid_credentials') {
      return 'Invalid email or password. Please check your credentials and try again.';
    }
    if (msg.contains('user already registered') || code == 'user_already_exists') {
      return 'An account with this email already exists. Please sign in instead.';
    }
    if (status == '429' ||
        msg.contains('over_email_send_rate_limit') ||
        msg.contains('rate limit') ||
        msg.contains('for security purposes') ||
        code == 'over_email_send_rate_limit') {
      return 'Too many email requests. For security, please wait a minute before requesting another confirmation email.';
    }
    if ((msg.contains('invalid') && msg.contains('email')) || code == 'email_address_invalid') {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('provider is not enabled') || msg.contains('unsupported provider')) {
      return 'Google Sign-In is not yet enabled in the Supabase project dashboard. Please configure the Google OAuth provider.';
    }
    return e.message;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
