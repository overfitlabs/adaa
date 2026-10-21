import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/auth_provider.dart';
import '../../../state/profile_provider.dart';
import '../../../state/wardrobe_provider.dart';
import '../../home/screens/home_screen.dart';
import '../../auth/screens/auth_screen.dart';

/// Stitch-designed ADAA Splash Screen (`c8f74c6fe2cc4b08a3cd5a0ef5c9536b` & `2511290488316267073`).
/// Features warm ivory canvas, organic botanical shadows, radiant ambient aura,
/// brand logo centerpiece, 4-point gold sparkle, and shimmering champagne progress bar.
class SplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration displayDuration;
  final bool autoNavigate;

  const SplashScreen({
    super.key,
    this.onComplete,
    this.displayDuration = const Duration(milliseconds: 1400),
    this.autoNavigate = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _shimmerAnim;
  late final Animation<double> _fadeAnim;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmupAndProceed();
    });
  }

  Future<void> _warmupAndProceed() async {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      try {
        context.read<ProfileProvider>().loadProfile(silent: true);
        context.read<WardrobeProvider>().loadWardrobe(silent: true);
      } catch (_) {}
    }

    if (!widget.autoNavigate) return;

    _navTimer = Timer(widget.displayDuration, () {
      if (!mounted) return;
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        final destination = auth.isAuthenticated ? const HomeScreen() : const AuthScreen();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => destination,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>().profile;
    final rawName = profile?.displayName ?? auth.displayName;
    final firstName = (rawName.isNotEmpty && rawName != 'Guest')
        ? rawName.split(' ').first
        : (auth.isAuthenticated ? 'there' : null);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          // Botanical Ambient Shadows (mimicking sunlight through foliage per Stitch design)
          Positioned(
            left: -80,
            bottom: 40,
            width: 320,
            height: 320,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.sage.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -100,
            top: -40,
            width: 360,
            height: 360,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main Center Content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 20),

                // Brand Centerpiece with Ambient Aura
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                    children: [
                      // Ambient Breathing Aura
                      Container(
                        width: 260,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.gold.withValues(alpha: 0.22),
                              AppColors.canvas.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      // Brand Logo Asset
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Image.asset(
                          'assets/branding/brand_name_tagline_logo.png',
                          width: 260,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/branding/brand_name_logo.png',
                              width: 220,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Text(
                                  'adaa',
                                  style: AppTypography.wordmarkLarge,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

                // Greeting & Champagne Shimmer Progress Indicator
                Padding(
                  padding: const EdgeInsets.only(bottom: 48, left: 24, right: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Golden Star Sparkle Icon
                      const Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: AppColors.gold,
                      ),
                      const SizedBox(height: 10),

                      // Personalized Salutation
                      Text(
                        firstName != null ? 'Hey, $firstName' : 'Welcome to adaa',
                        style: AppTypography.displayMedium.copyWith(
                          color: AppColors.forest,
                          fontWeight: FontWeight.w600,
                          fontSize: 26,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),

                      // Context Subtitle
                      Text(
                        firstName != null
                            ? 'GOOD TO SEE YOU AGAIN'
                            : 'YOUR STYLE, SMARTER',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Minimalist Champagne Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          width: 88,
                          height: 2.5,
                          color: AppColors.outlineVariant.withValues(alpha: 0.4),
                          child: AnimatedBuilder(
                            animation: _shimmerAnim,
                            builder: (context, child) {
                              return FractionallySizedBox(
                                alignment: Alignment(_shimmerAnim.value, 0.0),
                                widthFactor: 0.6,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppColors.gold,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
