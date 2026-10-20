import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../../state/auth_provider.dart';
import '../../home/screens/home_screen.dart';

/// Full-page strict authentication screen for `adaa`.
/// Shown whenever there is no valid authenticated session.
class AuthScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const AuthScreen({
    super.key,
    this.initialIsSignUp = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isSignUp;
  bool _isVerificationPending = false;
  String _pendingEmail = '';
  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    setState(() => _resendCooldownSeconds = seconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
      } else {
        setState(() => _resendCooldownSeconds--);
      }
    });
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    // Ensure all stale provider caches are cleared before logging in
    SessionManager.clearAllUserData(context);

    if (_isSignUp) {
      final result = await auth.signUpWithEmail(
        email,
        password,
        fullName: name.isNotEmpty ? name : null,
      );

      if (!mounted) return;

      if (result.status == SignUpResultStatus.needsEmailConfirmation) {
        setState(() {
          _isVerificationPending = true;
          _pendingEmail = email;
        });
        _startCooldown(60);
      } else if (result.status == SignUpResultStatus.alreadyRegistered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'An account with this email already exists. Please sign in.'),
            backgroundColor: Colors.amber.shade800,
          ),
        );
        setState(() {
          _isSignUp = false;
        });
      } else if (result.status == SignUpResultStatus.signedIn) {
        _navigateHomeIfMounted();
      }
    } else {
      final success = await auth.signInWithEmail(email, password);
      if (success && mounted) {
        _navigateHomeIfMounted();
      }
    }
  }

  void _navigateHomeIfMounted() {
    if (!mounted) return;
    // If AuthScreen was pushed on top of the navigator stack, pop or replace with HomeScreen
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _resendConfirmation(AuthProvider auth, String email) async {
    if (_resendCooldownSeconds > 0) return;
    final success = await auth.resendConfirmationEmail(email);
    if (success && mounted) {
      _startCooldown(60);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Confirmation link resent to $email. Please check your inbox.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<void> _continueWithGoogle(AuthProvider auth) async {
    SessionManager.clearAllUserData(context);
    final success = await auth.signInWithGoogle();
    if (success && mounted) {
      _navigateHomeIfMounted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo & Wordmark
                  const Center(
                    child: AdaaWordmark(
                      size: AdaaWordmarkSize.large,
                      color: AppColors.espresso,
                      withDotAccent: true,
                      showSubtitle: true,
                      subtitle: 'style intelligence & closet',
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Authentication Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [AppColors.cardShadow],
                    ),
                    child: _isVerificationPending
                        ? _buildVerificationPendingView(auth)
                        : _buildFormView(auth),
                  ),

                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'adaa strictly protects your wardrobe and privacy.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationPendingView(AuthProvider auth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accentSoft.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_unread_outlined, color: AppColors.primary, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'Verify Your Email',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a verification link to:\n$_pendingEmail',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _resendCooldownSeconds > 0
                ? null
                : () => _resendConfirmation(auth, _pendingEmail),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _resendCooldownSeconds > 0
                  ? 'Resend Link in $_resendCooldownSeconds s'
                  : 'Resend Verification Email',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _isVerificationPending = false;
              _isSignUp = false;
            });
          },
          child: const Text('Back to Sign In', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _buildFormView(AuthProvider auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Toggle for Sign In vs Sign Up
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isSignUp = false;
                        auth.clearError();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isSignUp ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_isSignUp ? [AppColors.subtleShadow] : null,
                      ),
                      child: Text(
                        'Sign In',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: !_isSignUp ? FontWeight.w800 : FontWeight.w600,
                          color: !_isSignUp ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isSignUp = true;
                        auth.clearError();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isSignUp ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isSignUp ? [AppColors.subtleShadow] : null,
                      ),
                      child: Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _isSignUp ? FontWeight.w800 : FontWeight.w600,
                          color: _isSignUp ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Error banner
          if (auth.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.errorMessage!,
                      style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Name field (Sign Up only)
          if (_isSignUp) ...[
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Alex Morgan',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (_isSignUp && (val == null || val.trim().isEmpty)) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'you@college.edu',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!val.contains('@') || !val.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please enter your password';
              }
              if (_isSignUp && val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),

          // Submit Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : () => _submit(auth),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isSignUp ? 'Create Account' : 'Sign In',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),

          // Google Sign-In Option
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.border)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('OR', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ),
              Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: auth.isLoading ? null : () => _continueWithGoogle(auth),
              icon: const Icon(Icons.g_mobiledata, size: 24, color: AppColors.primary),
              label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
