import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'auth_screen.dart';

/// Dedicated screen shown immediately following a successful logout.
/// Embodies Stitch "Logged Out" screen with verified session destruction.
class LogoutSuccessScreen extends StatelessWidget {
  const LogoutSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Stitch Brand Logo
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Image.asset(
                      'assets/branding/brand_name_logo.png',
                      height: 38,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Text(
                        'adaa',
                        style: AppTypography.wordmarkLarge,
                      ),
                    ),
                  ),

                  // Success Badge Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.outlineVariant, width: 0.8),
                      boxShadow: [AppColors.subtleShadow],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.sage.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            'SESSION SECURELY CLOSED',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.forest,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: AppColors.sageContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.forest,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Successfully Signed Out',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.forest,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All local session caches and authentication tokens have been cleanly invalidated. Your wardrobe data remains securely backed up.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Action 1: Sign back in
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(initialIsSignUp: false),
                                ),
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.forest,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                            ),
                            child: Text(
                              'Return to Sign In',
                              style: AppTypography.labelLarge.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action 2: Create new account
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(initialIsSignUp: true),
                                ),
                                (route) => false,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.forest,
                              side: const BorderSide(color: AppColors.forest, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                            ),
                            child: Text(
                              'Create New Account',
                              style: AppTypography.labelLarge.copyWith(color: AppColors.forest),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
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
}
