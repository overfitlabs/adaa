import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'auth_screen.dart';

/// Minimal logged-out screen for adaa.
class LogoutSuccessScreen extends StatelessWidget {
  const LogoutSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 384),
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: Column(
                          children: [
                            // Top branding
                            Padding(
                              padding: const EdgeInsets.only(top: 32),
                              child: Image.asset(
                                'assets/branding/brand_name_tagline_logo_web.png',
                                height: 40,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Text(
                                    'adaa',
                                    style: AppTypography.wordmarkLarge,
                                  );
                                },
                              ),
                            ),

                            // Quiet centered message
                            const Spacer(),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'You’re logged out.',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.headlineLarge.copyWith(
                                      fontSize: 28,
                                      height: 1.3,
                                      letterSpacing: -0.4,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'See you again soon.',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: AppColors.sage,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            // Bottom actions
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context)
                                            .pushAndRemoveUntil(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const AuthScreen(
                                                      initialIsSignUp: false,
                                                    ),
                                              ),
                                              (route) => false,
                                            );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.forestDark,
                                        foregroundColor: AppColors.white,
                                        elevation: 1,
                                        shadowColor: AppColors.forest
                                            .withValues(alpha: 0.12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            9999,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Log in again',
                                        style: AppTypography.labelLarge
                                            .copyWith(
                                              color: AppColors.white,
                                              fontSize: 14,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Inline create-account link
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'New to adaa? ',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.outline,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context)
                                              .pushAndRemoveUntil(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const AuthScreen(
                                                        initialIsSignUp: true,
                                                      ),
                                                ),
                                                (route) => false,
                                              );
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: AppColors.textDark,
                                        ),
                                        child: Text(
                                          'Create account',
                                          style: AppTypography.labelLarge
                                              .copyWith(
                                                color: AppColors.textDark,
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor:
                                                    AppColors.textDark,
                                                decorationThickness: 1,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
