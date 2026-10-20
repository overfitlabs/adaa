import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaa_brand_badge.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import 'auth_screen.dart';

/// Dedicated screen shown immediately following a successful logout.
/// Confirms session invalidation, data purge, and navigation history destruction,
/// before presenting clear path to sign back in or register.
class LogoutSuccessScreen extends StatelessWidget {
  const LogoutSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Brand Header
                const AdaaWordmark(
                  size: AdaaWordmarkSize.large,
                  color: AppColors.espresso,
                  withDotAccent: true,
                  showSubtitle: true,
                  subtitle: 'style intelligence & closet',
                ),
                const SizedBox(height: 36),

                // Success Badge Card
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [AppColors.cardShadow],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Successfully Signed Out',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your authentication session has been invalidated. All user-specific wardrobe pieces, community circles, borrowing requests, and local caches have been securely wiped.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const AdaaBrandBadge(text: 'SESSION SECURELY CLOSED'),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Action to return to Sign In
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Return to Sign In',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
