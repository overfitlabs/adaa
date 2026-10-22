import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/demo_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../state/auth_provider.dart';
import 'adaa_wordmark.dart';

/// Responsive desktop presentation shell for adaa.
///
/// On desktop and wide viewports (width >= 960px):
/// - Displays a luxury two-panel layout.
/// - Left panel: Editorial introduction, feature carousel, and one-click demo access.
/// - Right panel: Centered, realistic smartphone frame containing the live, interactive app.
///
/// On mobile viewports (width < 960px):
/// - Transparently passes through the app full-screen with native mobile behavior.
class WebResponsiveShell extends StatefulWidget {
  final Widget child;

  const WebResponsiveShell({super.key, required this.child});

  @override
  State<WebResponsiveShell> createState() => _WebResponsiveShellState();
}

class _WebResponsiveShellState extends State<WebResponsiveShell> {
  int _activeFeatureIndex = 0;
  Timer? _carouselTimer;
  Timer? _clockTimer;
  bool _isAutoAdvancePaused = false;
  bool _isDemoLoggingIn = false;
  String? _demoError;

  final List<Map<String, dynamic>> _features = const [
    {
      'title': 'Digital Wardrobe',
      'subtitle': 'Smart Closet Cataloging',
      'description':
          'Digitize your garments. adaa extracts categories, materials, and colors from photos for effortless cataloging.',
      'icon': Icons.checkroom,
      'badge': 'AI CATALOG',
      'tint': Color(0xFFF6EBE5),
      'accent': Color(0xFF733F2E),
    },
    {
      'title': 'AI Stylist',
      'subtitle': 'Personalized Lookbooks',
      'description':
          'Instant curated outfits tailored to your calendar, local weather, and personal aesthetic using pieces you already own.',
      'icon': Icons.auto_awesome,
      'badge': 'DAILY EDIT',
      'tint': Color(0xFFEBF2EC),
      'accent': Color(0xFF2E543A),
    },
    {
      'title': 'Virtual Try-On',
      'subtitle': 'Silhouette Look Simulation',
      'description':
          'Simulate garment pairings and preview your styled outfit combinations on realistic digital silhouettes before dressing.',
      'icon': Icons.view_in_ar,
      'badge': 'TRY-ON AI',
      'tint': Color(0xFFEFEBF6),
      'accent': Color(0xFF4A396B),
    },
    {
      'title': 'Campus Fashion Sharing',
      'subtitle': 'Community Shared Closets',
      'description':
          'Lend and borrow verified designer and vintage items securely within trusted campus circles and verified communities.',
      'icon': Icons.groups_outlined,
      'badge': 'COMMUNITY',
      'tint': Color(0xFFF6F2EB),
      'accent': Color(0xFF5C4D35),
    },
  ];

  @override
  void initState() {
    super.initState();
    _startCarouselTimer();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!_isAutoAdvancePaused && mounted) {
        setState(() {
          _activeFeatureIndex = (_activeFeatureIndex + 1) % _features.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  String get _currentLocalTime {
    final now = DateTime.now();
    final hour = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _handleDemoLogin(AuthProvider auth) async {
    setState(() {
      _isDemoLoggingIn = true;
      _demoError = null;
    });

    if (!DemoConfig.isConfigured) {
      setState(() {
        _isDemoLoggingIn = false;
        _demoError =
            'Demo credentials were not provided at build time via --dart-define. You can sign in or register directly using the phone screen.';
      });
      return;
    }

    try {
      final success = await auth.signInWithEmail(
        DemoConfig.demoEmail,
        DemoConfig.demoPassword,
      );

      if (!mounted) return;

      if (!success) {
        setState(() {
          _demoError = auth.errorMessage ??
              'Unable to sign into the demo account. Please verify that the credentials match the active Supabase project.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _demoError = 'Demo sign-in error: ${e.toString().replaceFirst("Exception: ", "")}';
      });
    } finally {
      if (mounted) {
        setState(() => _isDemoLoggingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isDesktop = screenSize.width >= 960;

    // Mobile / Narrow viewports: Render the real app full-screen natively
    if (!isDesktop) {
      return widget.child;
    }

    // Wide Viewports: Two-Panel Responsive Desktop Presentation Shell
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F3),
      body: Stack(
        children: [
          // Subtle luxury ambient decorative gradients
          Positioned(
            left: -120,
            top: -100,
            width: 500,
            height: 500,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.sage.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -100,
            bottom: -80,
            width: 600,
            height: 600,
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

          // Subtle status pill in the overall page's top-right corner.
          Positioned(
            top: 20,
            right: 24,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF8F3).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.borderLight.withValues(alpha: 0.9),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF398345),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Live Preview',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Balanced Two-Panel Composition
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Panel: Editorial Branding & Feature Showcase
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 36,
                            top: 24,
                            bottom: 24,
                          ),
                          child: _buildIntroPanel(context),
                        ),
                      ),
                    ),
                  ),

                  // Subtle Thin Vertical Divider
                  Container(
                    width: 1,
                    height: math.min(760.0, screenSize.height - 64.0),
                    color: AppColors.borderLight.withValues(alpha: 0.85),
                  ),

                  // Right Panel: Interactive Phone Frame Centered in its Allocated Area
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 36,
                          right: 20,
                          top: 20,
                          bottom: 20,
                        ),
                        child: _buildPhoneFrame(context, screenSize),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroPanel(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final activeFeature = _features[_activeFeatureIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Approved combined wordmark + tagline artwork.
        // Keep the existing widget as a graceful fallback if the asset is unavailable.
        Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/branding/brand_name_tagline_logo_web.png',
            width: 240,
            height: 58,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stackTrace) => const AdaaWordmark(
              size: AdaaWordmarkSize.large,
              showSubtitle: true,
              subtitle: 'your style, smarter',
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Editorial Heading
        Text(
          'Your style, curated\nand connected.',
          style: AppTypography.displayMedium.copyWith(
            color: AppColors.forest,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),

        // Brand Introduction
        Text(
          'adaa is your personal digital wardrobe, AI styling assistant, and university fashion-sharing platform. Catalog your closet effortlessly, discover fresh pairings, and lend or borrow pieces within trusted communities.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 28),

        // Auto-Advancing Feature Card Carousel
        MouseRegion(
          onEnter: (_) => setState(() => _isAutoAdvancePaused = true),
          onExit: (_) => setState(() => _isAutoAdvancePaused = false),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: Container(
              key: ValueKey<int>(_activeFeatureIndex),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: activeFeature['tint'] as Color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (activeFeature['accent'] as Color).withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (activeFeature['accent'] as Color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          activeFeature['badge'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: activeFeature['accent'] as Color,
                          ),
                        ),
                      ),
                      Icon(
                        activeFeature['icon'] as IconData,
                        size: 24,
                        color: activeFeature['accent'] as Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activeFeature['title'] as String,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: activeFeature['accent'] as Color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeFeature['description'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: (activeFeature['accent'] as Color).withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Carousel Indicators
        Row(
          children: List.generate(_features.length, (index) {
            final isSelected = index == _activeFeatureIndex;
            return GestureDetector(
              onTap: () => setState(() => _activeFeatureIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 6),
                width: isSelected ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.forest : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 32),

        // Demo Actions Section
        if (auth.isAuthenticated) ...[
          // State: Already authenticated
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.sageContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.forest, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demo Session Active',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.forest,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Signed in as ${auth.displayName}',
                        style: const TextStyle(fontSize: 11, color: AppColors.forest),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => auth.signOut(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),
        ] else ...[
          // State: Unauthenticated - Prominent "Explore Demo" CTA Button
          ElevatedButton(
            onPressed: _isDemoLoggingIn ? null : () => _handleDemoLogin(auth),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: AppColors.canvas,
              elevation: 4,
              shadowColor: AppColors.forest.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(double.infinity, 54),
            ),
            child: _isDemoLoggingIn
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFFC5A880), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Explore the Live Demo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
          ),

          if (_demoError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.missing.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.missing.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.missing),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _demoError!,
                      style: const TextStyle(fontSize: 11, color: AppColors.missing, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Or interact with login & signup directly inside the phone screen →',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

      ],
    );
  }

  Widget _buildPhoneFrame(BuildContext context, Size screenSize) {
    // Dynamically constrain phone dimensions to fit any laptop / desktop height safely
    final targetHeight = math.min(840.0, screenSize.height - 64.0);
    // Standard mobile aspect ratio (9 : 19.5)
    final targetWidth = (targetHeight * (9.0 / 19.5)).clamp(360.0, 410.0);

    return Container(
      width: targetWidth,
      height: targetHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF181C19),
        borderRadius: BorderRadius.circular(46),
        border: Border.all(
          color: const Color(0xFF2E3530),
          width: 8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.20),
            blurRadius: 40,
            spreadRadius: 4,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: Container(
          color: AppColors.background,
          child: Stack(
            children: [
              // Inner Phone Screen Canvas containing the live Flutter application
              Positioned.fill(
                child: MediaQuery(
                  // Inject mobile-like screen parameters inside the phone frame
                  data: MediaQuery.of(context).copyWith(
                    size: Size(targetWidth - 16, targetHeight - 16),
                    padding: const EdgeInsets.only(top: 44, bottom: 20),
                  ),
                  child: widget.child,
                ),
              ),

              // Realistic Phone Status Bar Simulation (part of frame, not app content)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 44,
                child: IgnorePointer(
                  child: _buildPhoneStatusBar(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStatusBar(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0.95),
            AppColors.background.withValues(alpha: 0.80),
            AppColors.background.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.75, 1.0],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Local Time
          SizedBox(
            width: 68,
            child: Text(
              _currentLocalTime,
              style: const TextStyle(
                color: AppColors.forest,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // Center: Dynamic Island camera cutout
          Expanded(
            child: Center(
              child: Container(
                width: 82,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF151916),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 3.5,
                          height: 3.5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0B1420),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right: Cellular + Wi-Fi + Battery indicators
          SizedBox(
            width: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildCellularSignal(),
                const SizedBox(width: 5),
                const Icon(
                  Icons.wifi,
                  size: 13,
                  color: AppColors.forest,
                ),
                const SizedBox(width: 5),
                _buildBatteryIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellularSignal() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSignalBar(height: 3.5),
        const SizedBox(width: 1.5),
        _buildSignalBar(height: 5.5),
        const SizedBox(width: 1.5),
        _buildSignalBar(height: 7.5),
        const SizedBox(width: 1.5),
        _buildSignalBar(height: 9.5),
      ],
    );
  }

  Widget _buildSignalBar({required double height}) {
    return Container(
      width: 2.2,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(0.8),
      ),
    );
  }

  Widget _buildBatteryIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 19,
          height: 10,
          padding: const EdgeInsets.all(1.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2.8),
            border: Border.all(
              color: AppColors.forest,
              width: 1.1,
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 13,
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(1.2),
              ),
            ),
          ),
        ),
        Container(
          width: 1.4,
          height: 3.5,
          decoration: const BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(0.8),
              bottomRight: Radius.circular(0.8),
            ),
          ),
        ),
      ],
    );
  }
}
