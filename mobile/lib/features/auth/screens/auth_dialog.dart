import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/auth_provider.dart';

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AuthDialog(),
    );
  }

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  bool _isSignUp = false;
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
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${auth.displayName}!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } else {
      final success = await auth.signInWithEmail(email, password);
      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${auth.displayName}!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
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
    final success = await auth.signInWithGoogle();
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final mediaQuery = MediaQuery.of(context);

    // If an incoming deep link confirmed the user while dialog is open, auto-close
    if (auth.isAuthenticated && _isVerificationPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email verified! Signed in as ${auth.email}'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      });
    }

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: _isVerificationPending
              ? _buildVerificationPendingView(auth)
              : _buildAuthFormView(auth),
        ),
      ),
    );
  }

  Widget _buildVerificationPendingView(AuthProvider auth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: AppColors.primary,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Check your email to verify your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade700),
            children: [
              const TextSpan(text: 'We sent a verification link to\n'),
              TextSpan(
                text: _pendingEmail,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const TextSpan(
                text: '.\n\nPlease open the link on this device to return to adaa and activate your account.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (auth.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              auth.errorMessage!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade800),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (auth.infoMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Text(
              auth.infoMessage!,
              style: TextStyle(fontSize: 12, color: Colors.green.shade800),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Resend button
        OutlinedButton.icon(
          icon: auth.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(
            _resendCooldownSeconds > 0
                ? 'Resend email in ${_resendCooldownSeconds}s'
                : 'Resend confirmation email',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: (auth.isLoading || _resendCooldownSeconds > 0)
              ? null
              : () => _resendConfirmation(auth, _pendingEmail),
        ),
        const SizedBox(height: 10),

        TextButton(
          onPressed: () {
            setState(() {
              _isVerificationPending = false;
              _isSignUp = false;
              _emailController.text = _pendingEmail;
              auth.clearError();
              auth.clearInfo();
            });
          },
          child: const Text(
            'Already verified? Sign in',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthFormView(AuthProvider auth) {
    final emailForResend = _emailController.text.trim();
    final isEmailNotConfirmedError =
        auth.errorMessage != null && auth.errorMessage!.toLowerCase().contains('not verified');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isSignUp ? 'join adaa' : 'welcome to adaa',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.3,
                color: AppColors.espresso,
                fontFamily: 'serif',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _isSignUp
              ? 'join your fashion & personal style community'
              : 'sign in to access your digital wardrobe and style circle',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        if (auth.infoMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    auth.infoMessage!,
                    style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: auth.clearInfo,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (auth.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        auth.errorMessage!,
                        style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: auth.clearError,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                if (isEmailNotConfirmedError && emailForResend.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.send, size: 14, color: AppColors.primary),
                    label: Text(
                      'Resend confirmation to $emailForResend',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    onPressed: () => _resendConfirmation(auth, emailForResend),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Google OAuth Button
        OutlinedButton.icon(
          icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
          label: const Text(
            'Continue with Google',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: auth.isLoading ? null : () => _continueWithGoogle(auth),
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or continue with email', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 16),

        Form(
          key: _formKey,
          child: Column(
            children: [
              if (_isSignUp) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g. Alex Rivera',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'student@campus.edu',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter an email';
                  if (!val.contains('@') || !val.contains('.')) return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
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
                  if (val == null || val.isEmpty) return 'Please enter a password';
                  if (val.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E1E2C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: auth.isLoading ? null : () => _submit(auth),
          child: auth.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  _isSignUp ? 'Create Account' : 'Sign In',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
        ),

        const SizedBox(height: 14),
        TextButton(
          onPressed: auth.isLoading
              ? null
              : () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                    auth.clearError();
                    auth.clearInfo();
                  });
                },
          child: Text(
            _isSignUp
                ? 'Already have an account? Sign in'
                : "Don't have an account? Create one",
            style: TextStyle(
              fontSize: 13,
              color: Colors.indigo.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
