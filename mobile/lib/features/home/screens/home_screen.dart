// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/models/garment_item.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/adaa_brand_badge.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/analysis_provider.dart';
import '../../../state/auth_provider.dart';
import '../../../state/community_provider.dart';
import '../../../state/outfits_provider.dart';
import '../../../state/wardrobe_provider.dart';
import '../../analysis/screens/analysis_detail_screen.dart';
import '../../analysis/screens/item_review_screen.dart';
import '../../communities/screens/communities_screen.dart';
import '../../communities/screens/shared_closet_screen.dart';
import '../../outfits/screens/outfits_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../styling/screens/recommendations_screen.dart';
import '../../styling/screens/adaa_chat_screen.dart';
import '../../tryon/screens/tryon_screen.dart';
import '../../communities/screens/shared_item_detail_screen.dart';
import '../../communities/widgets/public_profile_sheet.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../wardrobe/screens/wardrobe_detail_screen.dart';
import '../../wardrobe/screens/wardrobe_screen.dart';
import '../../../state/notification_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  int _currentTabIndex = 0;
  bool _isBackendConnected = false;
  bool _isCheckingHealth = true;

  @override
  void initState() {
    super.initState();
    _checkHealthAndLoadData();
  }

  Future<void> _checkHealthAndLoadData() async {
    setState(() => _isCheckingHealth = true);
    // Auto-detect reachable host (e.g. adb reverse 127.0.0.1:8000 vs 10.0.2.2:8000)
    final connected = await ApiClient.autoDetectBaseUrl();
    if (mounted) {
      setState(() {
        _isBackendConnected = connected;
        _isCheckingHealth = false;
      });
      if (connected) {
        context.read<WardrobeProvider>().loadWardrobe(silent: true);
        context.read<AnalysisProvider>().loadHistory();
        context.read<OutfitsProvider>().loadOutfits();
        context.read<CommunityProvider>().loadMyCommunities(silent: true);
        context.read<CommunityProvider>().loadSharedCloset(silent: true);
        try {
          context.read<NotificationProvider>().loadNotifications(silent: true);
          context.read<NotificationProvider>().loadUnreadCount(silent: true);
        } catch (_) {}
      }
    }
  }

  Future<void> _pickAndAnalyzeImage(
    ImageSource source, {
    ItemReviewIntent? intent,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (!mounted) return;

      if (intent == ItemReviewIntent.addToCloset) {
        await _runWardrobeDetection(picked);
      } else {
        await _runAnalysis(picked, intent: intent);
      }
    } catch (e) {
      if (mounted) {
        _showAnalysisErrorDialog('Failed to pick image: $e', intent: intent);
      }
    }
  }

  Future<void> _runWardrobeDetection(XFile file) async {
    bool dialogPopped = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _AnalyzingDialog(
        title: 'Detecting Garments...',
        subtitle: 'Isolating pieces and extracting metadata for your closet...',
      ),
    );

    try {
      final data = await ApiClient.detectWardrobeItemFromPhoto(file);
      if (mounted && !dialogPopped) {
        dialogPopped = true;
        Navigator.of(context, rootNavigator: true).pop();
      }

      final rawItems = data['detected_items'] as List<dynamic>? ?? [];
      final items = rawItems
          .map((e) => DetectedFashionItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final sourceUrl =
          data['detected_item']?['extracted_image_url'] as String? ??
          (items.isNotEmpty ? items.first.extractedImageUrl : null);

      if (items.isEmpty && mounted) {
        _showAnalysisErrorDialog(
          'No clear garments could be detected in the uploaded photo. Please try a clearer angle.',
          intent: ItemReviewIntent.addToCloset,
        );
        return;
      }

      if (mounted) {
        final res = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ItemReviewScreen(
              customItems: items,
              sourceImageUrl: sourceUrl,
              initialIntent: ItemReviewIntent.addToCloset,
            ),
          ),
        );

        if (res == true && mounted) {
          // Immediately refresh personal wardrobe and seamlessly navigate to My Closet tab
          await context.read<WardrobeProvider>().loadWardrobe(silent: false);
          setState(() => _currentTabIndex = 2);
        }
      }
    } catch (e) {
      if (mounted && !dialogPopped) {
        dialogPopped = true;
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        _showAnalysisErrorDialog(
          'Detection error: $e',
          intent: ItemReviewIntent.addToCloset,
        );
      }
    } finally {
      if (mounted && !dialogPopped) {
        dialogPopped = true;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _runAnalysis(XFile file, {ItemReviewIntent? intent}) async {
    final analysisProv = context.read<AnalysisProvider>();
    bool dialogPopped = false;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _AnalyzingDialog(),
    );

    try {
      final success = await analysisProv.analyzeImage(file);
      if (mounted && !dialogPopped) {
        dialogPopped = true;
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (success && mounted && analysisProv.currentAnalysis != null) {
        final res = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ItemReviewScreen(
              analysis: analysisProv.currentAnalysis!,
              initialIntent: intent,
            ),
          ),
        );
        if (res == true && mounted) {
          context.read<WardrobeProvider>().loadWardrobe(silent: true);
        }
      } else if (mounted) {
        _showAnalysisErrorDialog(
          analysisProv.error ?? 'Failed to analyze outfit image.',
          intent: intent,
        );
      }
    } catch (e) {
      if (mounted && !dialogPopped) {
        dialogPopped = true;
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        _showAnalysisErrorDialog('Analysis error: $e', intent: intent);
      }
    } finally {
      if (mounted && !dialogPopped) {
        dialogPopped = true;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _showAnalysisErrorDialog(
    String errorMessage, {
    ItemReviewIntent? intent,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.missing, size: 24),
            SizedBox(width: 8),
            Text(
              'Analysis Failed',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.dns_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Server: ${ApiEndpoints.baseUrl}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showServerConfigDialog();
            },
            child: const Text('Change Server'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Dismiss',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            onPressed: () {
              Navigator.pop(ctx);
              final lastFile = context
                  .read<AnalysisProvider>()
                  .lastAnalyzedFile;
              if (lastFile != null) {
                _runAnalysis(lastFile, intent: intent);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: ApiEndpoints.baseUrl);
    bool testing = false;
    String? testResult;
    bool? testSuccess;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Server Connection',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Specify the backend server URL for adaa.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Backend Base URL',
                      hintText: 'http://127.0.0.1:8000',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Quick Presets:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        label: const Text(
                          'USB ADB (127.0.0.1)',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () => setDialogState(
                          () => controller.text = 'http://127.0.0.1:8000',
                        ),
                      ),
                      ActionChip(
                        label: const Text(
                          'Emulator (10.0.2.2)',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () => setDialogState(
                          () => controller.text = 'http://10.0.2.2:8000',
                        ),
                      ),
                      ActionChip(
                        label: const Text(
                          'Wi-Fi (192.168.1.11)',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () => setDialogState(
                          () => controller.text = 'http://192.168.1.11:8000',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (testing)
                    const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Testing connection...',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    )
                  else if (testResult != null)
                    Row(
                      children: [
                        Icon(
                          testSuccess == true
                              ? Icons.check_circle
                              : Icons.error,
                          color: testSuccess == true
                              ? AppColors.exactMatch
                              : AppColors.missing,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            testResult!,
                            style: TextStyle(
                              fontSize: 12,
                              color: testSuccess == true
                                  ? AppColors.exactMatch
                                  : AppColors.missing,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: testing
                    ? null
                    : () async {
                        setDialogState(() {
                          testing = true;
                          testResult = null;
                        });
                        final ok = await ApiClient.checkHealth(
                          controller.text.trim(),
                        );
                        setDialogState(() {
                          testing = false;
                          testSuccess = ok;
                          testResult = ok
                              ? 'Connected successfully! (HTTP 200)'
                              : 'Could not reach server at this URL.';
                        });
                      },
                child: const Text('Test Connection'),
              ),
              ElevatedButton(
                onPressed: () {
                  ApiEndpoints.setBaseUrl(controller.text.trim());
                  Navigator.pop(ctx);
                  _checkHealthAndLoadData();
                },
                child: const Text('Save & Connect'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showImageSourceModal({ItemReviewIntent? intent}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                intent == ItemReviewIntent.addToCloset
                    ? 'Add to My Closet'
                    : intent == ItemReviewIntent.findPiece
                    ? 'Find a Matching Piece'
                    : 'Upload Outfit Photo',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                intent == ItemReviewIntent.addToCloset
                    ? 'Snap or select garments to isolate each piece and catalog them in your personal closet.'
                    : intent == ItemReviewIntent.findPiece
                    ? 'Select an inspiration photo to isolate a garment and search across your collection.'
                    : 'Select a photo featuring an outfit, flat-lay garments, or street style.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAnalyzeImage(ImageSource.gallery, intent: intent);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAnalyzeImage(ImageSource.camera, intent: intent);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 68,
      automaticallyImplyLeading: false,

      // Left: App icon
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          'assets/branding/app_icon_no_bg.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.checkroom_rounded,
            color: AppColors.espresso,
            size: 27,
          ),
        ),
      ),

      // Center: Brand wordmark
      title: const AdaaWordmark(
        size: AdaaWordmarkSize.medium,
        color: AppColors.espresso,
        withDotAccent: true,
        showSubtitle: true,
        subtitle: 'style intelligence & closet',
      ),
      centerTitle: true,
      titleSpacing: 0,

      // Right: Notifications
      actions: [
        Builder(
          builder: (ctx) {
            NotificationProvider? notifProv;
            try {
              notifProv = ctx.watch<NotificationProvider>();
            } catch (_) {
              notifProv = null;
            }

            final unread = notifProv?.unreadCount ?? 0;

            return IconButton(
              tooltip: 'Activity & Notifications',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              icon: Badge(
                isLabelVisible: unread > 0,
                backgroundColor: AppColors.terracotta,
                label: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 25,
                  color: AppColors.espresso,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    final outfits = context.watch<OutfitsProvider>();
    final analysisProv = context.watch<AnalysisProvider>();
    final communityProv = context.watch<CommunityProvider>();

    return Scaffold(
      appBar: _buildHomeAppBar(),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          // 0: Home tab
          _buildHomeFeedTab(wardrobe, outfits, analysisProv, communityProv),
          // 1: Communities tab
          const CommunitiesScreen(),
          // 2: My Closet tab
          const WardrobeScreen(),
          // 3: Profile tab
          ProfileScreen(
            onNavigateToCloset: () => setState(() => _currentTabIndex = 2),
            onNavigateToCommunities: () => setState(() => _currentTabIndex = 1),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() => _currentTabIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.espresso,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups),
              label: 'communities',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checkroom_outlined),
              activeIcon: Icon(Icons.checkroom),
              label: 'my closet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeFeedTab(
    WardrobeProvider wardrobe,
    OutfitsProvider outfits,
    AnalysisProvider analysisProv,
    CommunityProvider communityProv,
  ) {
    return RefreshIndicator(
      onRefresh: _checkHealthAndLoadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personalized Greeting Header
            _buildGreetingHeader(),
            const SizedBox(height: 16),

            // Persistent Ask adaa Stylist Entry Point (Option 1)
            _buildAskAdaaCard(),
            const SizedBox(height: 16),

            // Quick Action Tiles (2x2 Grid)
            _buildQuickTilesGrid(outfits),
            const SizedBox(height: 24),

            // Look of the Day / Stylist Pick
            _buildLookOfTheDay(),
            const SizedBox(height: 24),

            // Curated for Occasion Carousel
            _buildOccasionCarousel(),
            const SizedBox(height: 24),

            // Hero AI Outfit Intelligence Scanner
            _buildInspirationHero(),
            const SizedBox(height: 24),

            // Community Shared Closet Feed Section
            _buildCommunityFeedSection(communityProv),
            const SizedBox(height: 28),

            // Recent Analyses Section
            if (analysisProv.history.isNotEmpty) ...[
              const Text(
                'RECENT ANALYSES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 205,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: analysisProv.history.length,
                  itemBuilder: (ctx, idx) {
                    final item = analysisProv.history[idx];
                    return GestureDetector(
                      onTap: () {
                        analysisProv.setAnalysis(item);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AnalysisDetailScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 1.0,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                                child: PrivateImageView(
                                  imageUrl: item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    color: AppColors.accentSoft,
                                    child: const Icon(
                                      Icons.image_outlined,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.vibeOrStyle.isNotEmpty
                                          ? item.vibeOrStyle
                                          : 'Outfit Look',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.detectedGarmentCount} pieces',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    final auth = context.watch<AuthProvider>();
    final rawName = auth.displayName.trim();
    final firstName = rawName.isNotEmpty && rawName != 'Guest'
        ? rawName.split(' ').first
        : 'there';

    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 14, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(
              'YOUR AI STYLE STUDIO',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$timeGreeting, $firstName',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.forest,
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ready to curate your look today?',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildAskAdaaCard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdaaChatScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A2B), Color(0xFF14271D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A2B).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Color(0xFFE5C07B),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ask adaa',
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37)
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AI STYLIST',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE5C07B),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'What should I wear? Outfit pairings & styling',
                    style: AppTypography.bodySmall.copyWith(
                      color: const Color(0xFFD0D7D2),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTilesGrid(OutfitsProvider outfits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STUDIO SUITE',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            // Tile 1: Organize Wardrobe (Terracotta / Sand tint)
            _buildQuickTileCard(
              bgColor: const Color(0xFFF6EBE5),
              iconBg: const Color(0xFFEBD8CE),
              iconColor: const Color(0xFF733F2E),
              textColor: const Color(0xFF462417),
              subColor: const Color(0xFF733F2E),
              icon: Icons.checkroom,
              title: 'Organize\nWardrobe',
              subtitle: 'AI Cataloging',
              onTap: () => setState(() => _currentTabIndex = 2),
            ),
            // Tile 2: AI Style Suggestions (Sage tint)
            _buildQuickTileCard(
              bgColor: const Color(0xFFEBF2EC),
              iconBg: const Color(0xFFD4E3D7),
              iconColor: const Color(0xFF2E543A),
              textColor: const Color(0xFF183521),
              subColor: const Color(0xFF2E543A),
              icon: Icons.auto_awesome,
              title: 'AI Style\nSuggestions',
              subtitle: 'Fresh Pairings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecommendationsScreen(),
                ),
              ),
            ),
            // Tile 3: Virtual Try-On (Lavender tint)
            _buildQuickTileCard(
              bgColor: const Color(0xFFEFEBF6),
              iconBg: const Color(0xFFDDD6EC),
              iconColor: const Color(0xFF4A396B),
              textColor: const Color(0xFF2A1E45),
              subColor: const Color(0xFF4A396B),
              icon: Icons.view_in_ar,
              title: 'Virtual\nTry-On',
              subtitle: 'Look Simulation',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TryOnScreen()),
              ),
            ),
            // Tile 4: Saved Favorites (Champagne tint)
            _buildQuickTileCard(
              bgColor: const Color(0xFFF6F2EB),
              iconBg: const Color(0xFFE7DECF),
              iconColor: const Color(0xFF5C4D35),
              textColor: const Color(0xFF382D1B),
              subColor: const Color(0xFF5C4D35),
              icon: Icons.favorite,
              title: 'Saved\nFavorites',
              subtitle: '${outfits.outfits.length} Outfits',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OutfitsScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickTileCard({
    required Color bgColor,
    required Color iconBg,
    required Color iconColor,
    required Color textColor,
    required Color subColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconBg.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: subColor.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLookOfTheDay() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.subtleShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Look of the Day',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.forest,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Text(
                  'STYLIST PICK',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.sage,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // Hero Banner
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2E4E3E),
                      AppColors.forest,
                      Color(0xFF13241C),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TAILORING • AUTUMN CAPSULE',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Autumn Tailoring',
                      style: AppTypography.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pairing your tailored blazer with relaxed wide-leg trousers.',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DAILY EDIT',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.forest,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Action row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TryOnScreen()),
                    ),
                    icon: const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: AppColors.gold,
                    ),
                    label: const Text('Virtual Try-On'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecommendationsScreen(),
                    ),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.sageContainer,
                    foregroundColor: AppColors.forest,
                  ),
                  icon: const Icon(Icons.tune, size: 20),
                  tooltip: 'Tune Styling',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccasionCarousel() {
    final occasions = [
      {
        'title': 'Weekend Brunch',
        'sub': 'Relaxed & chic',
        'icon': Icons.local_cafe_outlined,
        'pcs': '4 pcs',
      },
      {
        'title': 'Boardroom Polish',
        'sub': 'Sharp tailoring',
        'icon': Icons.business_center_outlined,
        'pcs': '3 pcs',
      },
      {
        'title': 'Cocktail Hour',
        'sub': 'Evening glamour',
        'icon': Icons.nightlife_outlined,
        'pcs': '4 pcs',
      },
      {
        'title': 'Airport Layering',
        'sub': 'Cozy elegant',
        'icon': Icons.flight_takeoff_outlined,
        'pcs': '5 pcs',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Curated for Occasion',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.forest,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecommendationsScreen(),
                ),
              ),
              child: Text(
                'Explore all',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.sage,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: occasions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) {
              final occ = occasions[idx];
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecommendationsScreen(
                      initialOccasion: occ['title'] as String,
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 136,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [AppColors.subtleShadow],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            occ['icon'] as IconData,
                            size: 20,
                            color: AppColors.forest,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.sageContainer,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              occ['pcs'] as String,
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            occ['title'] as String,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.forest,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            occ['sub'] as String,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInspirationHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.espresso,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.terracotta,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'AI OUTFIT INTELLIGENCE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Decode Any Outfit. Match Your Closet.',
            style: AppTypography.displayLarge.copyWith(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload inspiration from street style, archives, or flat-lays to deconstruct every piece and match your closet.',
            style: TextStyle(
              color: AppColors.sandSoft,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),

          // Two Prominent Hero Actions: "Add to my closet" and "Find a piece"
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showImageSourceModal(
                    intent: ItemReviewIntent.addToCloset,
                  ),
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 16,
                  ),
                  label: const Text(
                    'Add to my closet',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warmIvory,
                    foregroundColor: AppColors.espresso,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showImageSourceModal(intent: ItemReviewIntent.findPiece),
                  icon: const Icon(Icons.search, size: 16, color: Colors.white),
                  label: const Text(
                    'Find a piece',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70, width: 1.2),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // General Upload Entry Point
          // Center(
          //   child: TextButton.icon(
          //     onPressed: () => _showImageSourceModal(intent: null),
          //     icon: const Icon(
          //       Icons.arrow_upward_rounded,
          //       size: 14,
          //       color: AppColors.sandSoft,
          //     ),
          //     label: const Text(
          //       'Upload Outfit Photo',
          //       style: TextStyle(
          //         color: AppColors.sandSoft,
          //         fontSize: 11,
          //         fontWeight: FontWeight.w600,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildCommunityFeedSection(CommunityProvider communityProv) {
    final approvedCommunities = communityProv.approvedCommunities;
    final sharedItems = communityProv.sharedClosetItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMMUNITY SHARED CLOSET',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  approvedCommunities.isNotEmpty
                      ? 'Pieces shared across your ${approvedCommunities.length} approved circles'
                      : 'Shared wardrobes from style circles',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            if (sharedItems.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SharedClosetScreen()),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (communityProv.isLoading && sharedItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: const Column(
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
                SizedBox(height: 12),
                Text(
                  'Loading community pieces...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else if (approvedCommunities.isEmpty)
          // Feed empty state: user has joined no approved communities
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.terracottaSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      color: AppColors.terracotta,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Join Style Circles',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.espresso,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Connect with curated fashion communities to borrow pieces, browse shared closets, and exchange styling inspiration.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _currentTabIndex = 1),
                  icon: const Icon(Icons.explore_outlined, size: 16),
                  label: const Text('Discover Communities'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.espresso,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (sharedItems.isEmpty)
          // Approved communities exist, but no shared items yet
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.checkroom_outlined,
                      color: AppColors.accent,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Shared Closets are Empty',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'No pieces have been shared yet in your circles. Be the first to share a piece from your wardrobe!',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentTabIndex = 2),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Share from My Closet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          // Rich horizontal feed of shared pieces
          SizedBox(
            height: 255,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sharedItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (ctx, idx) {
                final shared = sharedItems[idx];
                final garment = shared.item;
                final currentUserId = context.read<AuthProvider>().user?.id;
                final isOwner =
                    currentUserId != null && currentUserId == shared.ownerId;

                return GestureDetector(
                  onTap: () {
                    if (isOwner) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WardrobeDetailScreen(item: garment),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SharedItemDetailScreen(sharedItem: shared),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: 155,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [AppColors.cardShadow],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: AppColors.surfaceContainerLow),
                                Center(
                                  child: PrivateImageView(
                                    imageUrl: garment.imageUrl,
                                    fit: BoxFit.contain,
                                    backgroundColor:
                                        AppColors.surfaceContainerLow,
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.espresso.withValues(
                                        alpha: 0.8,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      shared.communityName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(
                                  garment.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Owner Attribution
                                InkWell(
                                  onTap: () => PublicProfileSheet.show(
                                    context,
                                    userId: shared.ownerId,
                                    fallbackName: shared.resolvedOwnerName,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 8,
                                        backgroundColor: AppColors.accentSoft,
                                        child: Text(
                                          shared.ownerInitials,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          shared.resolvedOwnerName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    AdaaBrandBadge(
                                      text: garment.category.toUpperCase(),
                                    ),
                                    if (garment.primaryColor.isNotEmpty)
                                      Text(
                                        garment.primaryColor,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _AnalyzingDialog extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AnalyzingDialog({
    this.title = 'Analyzing Outfit...',
    this.subtitle = 'Identifying garments, silhouettes, colors, and extracting candidate pieces...',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.terracotta,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
