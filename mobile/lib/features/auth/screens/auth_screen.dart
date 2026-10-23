import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../../state/auth_provider.dart';
import '../../home/screens/home_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const AuthScreen({super.key, this.initialIsSignUp = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isSignUp;
  bool _isVerificationPending = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  String _pendingEmail = '';
  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();

    setState(() => _resendCooldownSeconds = seconds);

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

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.forest,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateHomeIfMounted() {
    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSignUp && !_acceptTerms) {
      _showMessage('Please accept the terms to continue.', error: true);
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    SessionManager.clearAllUserData(context);

    if (_isSignUp) {
      final result = await auth.signUpWithEmail(
        email,
        password,
        fullName: name,
      );

      if (!mounted) return;

      switch (result.status) {
        case SignUpResultStatus.needsEmailConfirmation:
          setState(() {
            _isVerificationPending = true;
            _pendingEmail = email;
          });
          _startCooldown();

        case SignUpResultStatus.alreadyRegistered:
          _showMessage(
            result.message ?? 'Account already exists. Please sign in.',
            error: true,
          );
          setState(() {
            _isSignUp = false;
          });

        case SignUpResultStatus.signedIn:
          _navigateHomeIfMounted();

        case SignUpResultStatus.failed:
          _showMessage(
            result.message ??
                auth.errorMessage ??
                'Unable to create your account.',
            error: true,
          );
      }
    } else {
      final success = await auth.signInWithEmail(email, password);

      if (!mounted) return;

      if (success) {
        _navigateHomeIfMounted();
      } else if (auth.errorMessage != null) {
        _showMessage(auth.errorMessage!, error: true);
      }
    }
  }

  Future<void> _forgotPassword(AuthProvider auth) async {
    final email = _emailController.text.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('Enter a valid email address first.', error: true);
      return;
    }

    final success = await auth.resetPasswordForEmail(email);

    if (!mounted) return;

    _showMessage(
      success
          ? 'Check your inbox for password reset instructions.'
          : auth.errorMessage ?? 'Unable to send the reset email.',
      error: !success,
    );
  }

  Future<void> _googleSignIn(AuthProvider auth) async {
    _showMessage('Google Sign in, but Google doesn\'t trust us yet');
    // final success = await auth.signInWithGoogle();

    // if (!mounted) return;

    // if (success) {
    //   // OAuth normally completes through the redirect/deep-link flow.
    //   // Do not navigate before the provider/session is actually ready.
    //   return;
    // }

    if (auth.errorMessage != null) {
      _showMessage(auth.errorMessage!, error: true);
    }
  }

  Future<void> _resendConfirmation(AuthProvider auth) async {
    if (_resendCooldownSeconds > 0 || auth.isLoading) {
      return;
    }

    final success = await auth.resendConfirmationEmail(_pendingEmail);

    if (!mounted) return;

    if (success) {
      _startCooldown();
      _showMessage('Confirmation email sent to $_pendingEmail');
    } else {
      _showMessage(
        auth.errorMessage ?? 'Unable to resend confirmation email.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),

                        Center(
                          child: const AdaaWordmark(
                            size: AdaaWordmarkSize.large,
                            showSubtitle: false,
                            useLogoAsset: true,
                          ),
                        ),

                        const SizedBox(height: 42),

                        if (_isVerificationPending)
                          _buildVerification(auth)
                        else
                          _buildAuthForm(auth),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthForm(AuthProvider auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isSignUp ? 'Your style journey starts here.' : 'Welcome back.',
            textAlign: TextAlign.center,
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isSignUp
                ? 'Create your personal style profile.'
                : 'Your curated wardrobe is waiting.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                _tab('Log in', !_isSignUp, () {
                  setState(() => _isSignUp = false);
                  auth.clearError();
                }),
                _tab('Create account', _isSignUp, () {
                  setState(() => _isSignUp = true);
                  auth.clearError();
                }),
              ],
            ),
          ),

          const SizedBox(height: 26),

          if (auth.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                auth.errorMessage!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_isSignUp) ...[
            _field(
              controller: _nameController,
              label: 'Full name',
              icon: Icons.person_outline,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Please enter your name'
                  : null,
              capitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
          ],

          _field(
            controller: _emailController,
            label: 'Email address',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                  .hasMatch(value.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          _field(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            suffix: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (_isSignUp && value.length < 6) {
                return 'Use at least 6 characters';
              }
              return null;
            },
          ),

          if (_isSignUp) ...[
            const SizedBox(height: 16),
            _field(
              controller: _confirmPasswordController,
              label: 'Confirm password',
              icon: Icons.lock_outline,
              obscure: _obscureConfirmPassword,
              suffix: IconButton(
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _acceptTerms,
              onChanged: (value) =>
                  setState(() => _acceptTerms = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.forest,
              title: Text(
                'I’m ready to elevate my style with adaa.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],

          if (!_isSignUp)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: auth.isLoading ? null : () => _forgotPassword(auth),
                child: Text(
                  'Forgot password?',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.forest,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 18),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : () => _submit(auth),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isSignUp ? 'Create account' : 'Log in',
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(child: Divider(color: AppColors.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OR',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.outlineVariant)),
            ],
          ),

          const SizedBox(height: 20),

          OutlinedButton(
            onPressed: auth.isLoading ? null : () => _googleSignIn(auth),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forest,
              minimumSize: const Size(double.infinity, 52),
              side: BorderSide(color: AppColors.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.g_mobiledata, size: 30),
                const SizedBox(width: 8),
                Text(
                  'Continue with Google',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.forest,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _isSignUp ? 'Already have an account? ' : 'New to adaa? ',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                    });
                    auth.clearError();
                  },
                  child: Text(
                    _isSignUp ? 'Log in' : 'Create account',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.forest,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.forest : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      textCapitalization: capitalization,
      autocorrect: false,
      validator: validator,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.forest),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildVerification(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_unread_outlined,
          size: 56,
          color: AppColors.forest,
        ),
        const SizedBox(height: 24),
        Text(
          'Check your inbox.',
          textAlign: TextAlign.center,
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.forest,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a verification link to',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _pendingEmail,
          textAlign: TextAlign.center,
          style: AppTypography.labelLarge.copyWith(color: AppColors.forest),
        ),
        const SizedBox(height: 12),
        Text(
          'Verify your email to finish creating your adaa account.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _resendCooldownSeconds > 0 || auth.isLoading
                ? null
                : () => _resendConfirmation(auth),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: auth.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _resendCooldownSeconds > 0
                        ? 'Resend in ${_resendCooldownSeconds}s'
                        : 'Resend confirmation email',
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () {
            setState(() {
              _isVerificationPending = false;
              _isSignUp = false;
            });
            auth.clearError();
          },
          child: Text(
            'Back to log in',
            style: AppTypography.labelLarge.copyWith(color: AppColors.forest),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Can’t find the email? Check your spam folder.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSubtle),
        ),
      ],
    );
  }
}
