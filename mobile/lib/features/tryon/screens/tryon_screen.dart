import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaa_wordmark.dart';

class TryOnScreen extends StatelessWidget {
  final String? prefilledInspirationUrl;
  final String? prefilledWardrobeItemId;

  const TryOnScreen({
    super.key,
    this.prefilledInspirationUrl,
    this.prefilledWardrobeItemId,
  });

  static const Color _background = Color(0xFFFCF9F4);
  static const Color _primary = Color(0xFF082217);
  static const Color _secondary = Color(0xFF456651);
  static const Color _muted = Color(0xFF424844);
  static const Color _surfaceLow = Color(0xFFF6F3EE);
  static const Color _gold = Color(0xFFC89142);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        title: const AdaaWordmark(
          size: AdaaWordmarkSize.medium,
          color: AppColors.espresso,
          withDotAccent: true,
          showSubtitle: true,
          subtitle: 'style intelligence & closet',
        ),
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 64,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primary,
            size: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              // Connect your existing notifications screen here.
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: _primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Coming Soon badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBE8E3),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('✦', style: TextStyle(color: _gold, fontSize: 13)),
                    SizedBox(width: 7),
                    Text(
                      'COMING SOON',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Hero fashion image
              LayoutBuilder(
                builder: (context, constraints) {
                  final heroHeight = (constraints.maxWidth * 1.25).clamp(
                    260.0,
                    380.0,
                  );

                  return Container(
                    width: double.infinity,
                    height: heroHeight,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _surfaceLow,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.09),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuCJRJ-F0Ho8aMwcYpndU2_zWmkW4oAZZ50Bu70z88enql9YqPNlGJwavwDrA2_y8-U9Ek0DK7tKSVFvzPsCZfPzT_ofhQ8801zrMgOBLwRLOR6KU0cnSVyDyqkxk6_a4rjg-QlkJrBJCsRHyvVC28e5kOyPAROf6dIaXIGIGAT6e0LuQLaslxrpPvjUJ7JYcOjK8kIp8FatcIq7mN6D4-vHCDDAovI8RSChkC89a5D_qYVN1AB5Rg9o4w',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFE5D9C8),
                              child: const Center(
                                child: Icon(
                                  Icons.checkroom_rounded,
                                  size: 72,
                                  color: _secondary,
                                ),
                              ),
                            );
                          },
                        ),

                        // Subtle bottom scrim
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0x00082217),
                                Color(0x4D082217),
                              ],
                            ),
                          ),
                        ),

                        // Preview badge
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _background.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 13,
                                  color: _gold,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'PREVIEW ONLY',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 25),

              // Editorial typography
              const Text(
                'Virtual Try-On',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 30,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.7,
                  color: _primary,
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                '“Your outfits, reimagined.”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 19,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                  color: _secondary,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Your personal virtual fitting room is on its way. '
                'For now, explore your wardrobe and discover outfit '
                'combinations with adaa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.8, color: _muted),
              ),

              const SizedBox(height: 22),

              // Feature highlights
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surfaceLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    _FeatureRow(
                      text: 'Photorealistic fitting on your silhouette',
                    ),
                    SizedBox(height: 15),
                    _FeatureRow(
                      text: 'Grounded in your actual registered wardrobe',
                    ),
                    SizedBox(height: 15),
                    _FeatureRow(text: 'Studio lighting & drape calibration'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Primary CTA
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E382B),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shadowColor: _primary.withValues(alpha: 0.12),
                    shape: const StadiumBorder(),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Explore My Wardrobe',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 9),
                      Icon(Icons.checkroom_rounded, size: 19),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Secondary CTA
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Discover Outfits',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 17),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;

  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFFC4E9CE),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 15,
            color: Color(0xFF456651),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF1C1C19),
            ),
          ),
        ),
      ],
    );
  }
}
