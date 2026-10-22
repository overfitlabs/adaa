import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../../state/auth_provider.dart';
import '../../home/screens/home_screen.dart';

/// Full-page strict authentication screen for `adaa`.
/// Embodies Stitch editorial luxury: warm ivory background, Deep Forest Green pill CTA,
/// Playfair Display headlines, and refined form inputs.
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
            backgroundColor: AppColors.gold,
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
          backgroundColor: AppColors.forest,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Stitch Brand Logo & Wordmark
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: AdaaWordmark(
                      size: AdaaWordmarkSize.large,
                      showSubtitle: true,
                      subtitle: 'campus sharing & wardrobe',
                      useLogoAsset: true,
                    ),
                  ),

                  // Headline & Subtitle (Playfair Display)
                  Text(
                    _isVerificationPending
                        ? 'Verify Your Email'
                        : _isSignUp
                            ? 'Create Style Profile.'
                            : 'Welcome back.',
                    style: AppTypography.displaySmall.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isVerificationPending
                        ? 'We sent a verification link to your registered email.'
                        : _isSignUp
                            ? 'Begin your intelligent digital wardrobe journey.'
                            : 'Enter your credentials to access your curated personal wardrobe.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Main Interactive Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.outlineVariant, width: 0.8),
                      boxShadow: [AppColors.subtleShadow],
                    ),
                    child: _isVerificationPending
                        ? _buildVerificationPendingView(auth)
                        : _buildFormView(auth),
                  ),

                  const SizedBox(height: 24),

                  // Footer note
                  Text(
                    'adaa • personal style intelligence & campus sharing',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSubtle,
                      letterSpacing: 0.8,
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
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: AppColors.sageContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_unread_outlined, color: AppColors.forest, size: 36),
        ),
        const SizedBox(height: 18),
        Text(
          'Verification Sent',
          style: AppTypography.headlineSmall.copyWith(color: AppColors.forest),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a verification link to:\n$_pendingEmail',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _resendCooldownSeconds > 0
                ? null
                : () => _resendConfirmation(auth, _pendingEmail),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
            ),
            child: Text(
              _resendCooldownSeconds > 0
                  ? 'Resend Link in $_resendCooldownSeconds s'
                  : 'Resend Verification Email',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
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
          child: Text('Back to Sign In', style: AppTypography.labelLarge.copyWith(color: AppColors.forest)),
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
          // Segmented Pill Toggle for Sign In vs Create Account
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9999),
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
                    borderRadius: BorderRadius.circular(9999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isSignUp ? AppColors.forest : Colors.transparent,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: !_isSignUp ? [AppColors.subtleShadow] : null,
                      ),
                      child: Text(
                        'Sign In',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelLarge.copyWith(
                          color: !_isSignUp ? Colors.white : AppColors.textSecondary,
                          fontWeight: !_isSignUp ? FontWeight.w700 : FontWeight.w500,
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
                    borderRadius: BorderRadius.circular(9999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isSignUp ? AppColors.forest : Colors.transparent,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: _isSignUp ? [AppColors.subtleShadow] : null,
                      ),
                      child: Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelLarge.copyWith(
                          color: _isSignUp ? Colors.white : AppColors.textSecondary,
                          fontWeight: _isSignUp ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Error banner
          if (auth.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.errorMessage!,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w500),
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
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textDark),
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Elena Rostova',
                prefixIcon: const Icon(Icons.person_outline, size: 20, color: AppColors.forest),
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
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textDark),
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'your.email@domain.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppColors.forest),
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
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textDark),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.forest),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
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
          const SizedBox(height: 24),

          // Primary Submit Pill Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : () => _submit(auth),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                elevation: 0,
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isSignUp ? 'Create Account' : 'Sign In',
                      style: AppTypography.labelLarge.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
