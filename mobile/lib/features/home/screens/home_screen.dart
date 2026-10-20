import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/adaa_brand_badge.dart';
import '../../../core/widgets/adaa_brand_sheet.dart';
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
import '../../tryon/screens/tryon_screen.dart';
import '../../communities/screens/shared_item_detail_screen.dart';
import '../../communities/widgets/public_profile_sheet.dart';
import '../../requests/screens/requests_screen.dart';
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

  Future<void> _pickAndAnalyzeImage(ImageSource source, {ItemReviewIntent? intent}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (!mounted) return;

      await _runAnalysis(picked, intent: intent);
    } catch (e) {
      if (mounted) {
        _showAnalysisErrorDialog('Failed to pick image: $e', intent: intent);
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

  void _showAnalysisErrorDialog(String errorMessage, {ItemReviewIntent? intent}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.missing, size: 24),
            SizedBox(width: 8),
            Text('Analysis Failed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
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
                  const Icon(Icons.dns_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Server: ${ApiEndpoints.baseUrl}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
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
            child: const Text('Dismiss', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            onPressed: () {
              Navigator.pop(ctx);
              final lastFile = context.read<AnalysisProvider>().lastAnalyzedFile;
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Server Connection', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Specify the backend server URL for adaa.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                  const Text('Quick Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        label: const Text('USB ADB (127.0.0.1)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() => controller.text = 'http://127.0.0.1:8000'),
                      ),
                      ActionChip(
                        label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() => controller.text = 'http://10.0.2.2:8000'),
                      ),
                      ActionChip(
                        label: const Text('Wi-Fi (192.168.1.11)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() => controller.text = 'http://192.168.1.11:8000'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (testing)
                    const Row(
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Testing connection...', style: TextStyle(fontSize: 12)),
                      ],
                    )
                  else if (testResult != null)
                    Row(
                      children: [
                        Icon(testSuccess == true ? Icons.check_circle : Icons.error, color: testSuccess == true ? AppColors.exactMatch : AppColors.missing, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            testResult!,
                            style: TextStyle(fontSize: 12, color: testSuccess == true ? AppColors.exactMatch : AppColors.missing),
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
                        final ok = await ApiClient.checkHealth(controller.text.trim());
                        setDialogState(() {
                          testing = false;
                          testSuccess = ok;
                          testResult = ok ? 'Connected successfully! (HTTP 200)' : 'Could not reach server at this URL.';
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
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: Icon(Icons.photo_library_outlined, color: AppColors.primary),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAnalyzeImage(ImageSource.gallery, intent: intent);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                ),
                title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
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
      title: GestureDetector(
        onTap: () => AdaaBrandSheet.show(context),
        behavior: HitTestBehavior.opaque,
        child: const AdaaWordmark(
          size: AdaaWordmarkSize.medium,
          color: AppColors.espresso,
          withDotAccent: true,
          showSubtitle: true,
          subtitle: 'style intelligence & closet',
        ),
      ),
      actions: [
        // User / Auth button
        Consumer<AuthProvider>(
          builder: (ctx, auth, _) {
            if (auth.isAuthenticated) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PopupMenuButton<String>(
                  tooltip: 'Account Menu',
                  offset: const Offset(0, 40),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text(auth.email ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 18),
                          SizedBox(width: 8),
                          Text('My Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Sign Out', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (val) {
                    if (val == 'logout') {
                      SessionManager.performLogout(context);
                    } else if (val == 'profile') {
                      setState(() => _currentTabIndex = 3);
                    }
                  },
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        // Activity & Notifications Button with Unread Badge
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
              icon: Badge(
                isLabelVisible: unread > 0,
                backgroundColor: AppColors.terracotta,
                label: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                child: const Icon(Icons.notifications_outlined, size: 22, color: AppColors.espresso),
              ),
            );
          },
        ),
        // Requests Button
        IconButton(
          icon: const Icon(Icons.handshake_outlined, size: 22, color: AppColors.espresso),
          tooltip: 'Borrowing Requests',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RequestsScreen()),
            );
          },
        ),
        // Connection pill
        Padding(
          padding: const EdgeInsets.only(right: 16),

          child: InkWell(
            onTap: _showServerConfigDialog,
            borderRadius: BorderRadius.circular(16),
            child: Tooltip(
              message: 'Tap to configure server connection',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isBackendConnected ? AppColors.exactMatch : AppColors.missing,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isCheckingHealth
                          ? 'Connecting...'
                          : _isBackendConnected
                              ? 'Online'
                              : 'Offline',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.settings, size: 12, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
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
      appBar: _currentTabIndex == 0 ? _buildHomeAppBar() : null,
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
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
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
            // Hero Inspiration Card with prominent actions
            _buildInspirationHero(),

            const SizedBox(height: 20),

            // Quick Overview Counters
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Wardrobe',
                    count: '${wardrobe.items.length}',
                    icon: Icons.checkroom_outlined,
                    onTap: () => setState(() => _currentTabIndex = 2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Saved Looks',
                    count: '${outfits.outfits.length}',
                    icon: Icons.auto_awesome_mosaic_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OutfitsScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Communities',
                    count: '${communityProv.myCommunities.length}',
                    icon: Icons.groups_outlined,
                    onTap: () => setState(() => _currentTabIndex = 1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Community Shared Closet Feed Section
            _buildCommunityFeedSection(communityProv),

            const SizedBox(height: 28),

            // Quick Action Tiles
            const Text(
              'FASHION SUITE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              title: 'Digital Wardrobe',
              subtitle: 'Catalog, search, and categorize your personal clothes',
              icon: Icons.checkroom,
              onTap: () => setState(() => _currentTabIndex = 2),
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              title: 'Communities & Shared Closets',
              subtitle: 'Explore student style circles and browse shared wardrobes',
              icon: Icons.groups_outlined,
              onTap: () => setState(() => _currentTabIndex = 1),
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              title: 'YouCam Virtual Try-On',
              subtitle: 'Preview inspiration looks rendered onto your own photo',
              icon: Icons.face_retouching_natural,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TryOnScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              title: 'Styling & Recommendations',
              subtitle: 'Discover personalized high-low mixes and capsule tips',
              icon: Icons.style_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecommendationsScreen()),
              ),
            ),

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
                height: 170,
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
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              child: PrivateImageView(
                                imageUrl: item.imageUrl,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  height: 100,
                                  color: AppColors.accentSoft,
                                  child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.vibeOrStyle.isNotEmpty ? item.vibeOrStyle : 'Outfit Look',
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
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
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
            'Decode Any Outfit.\nMatch Your Closet.',
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
                  onPressed: () => _showImageSourceModal(intent: ItemReviewIntent.addToCloset),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                  label: const Text(
                    'Add to my closet',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warmIvory,
                    foregroundColor: AppColors.espresso,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showImageSourceModal(intent: ItemReviewIntent.findPiece),
                  icon: const Icon(Icons.search, size: 16, color: Colors.white),
                  label: const Text(
                    'Find a piece',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // General Upload Entry Point
          Center(
            child: TextButton.icon(
              onPressed: () => _showImageSourceModal(intent: null),
              icon: const Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.sandSoft),
              label: const Text(
                'Upload Outfit Photo',
                style: TextStyle(color: AppColors.sandSoft, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
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
                      : 'Shared wardrobes from campus circles',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
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
                CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                SizedBox(height: 12),
                Text('Loading community pieces...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                    Icon(Icons.groups_outlined, color: AppColors.terracotta, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Join Campus Circles',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.espresso),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Connect with student fashion communities to borrow pieces, browse shared closets, and exchange styling inspiration.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _currentTabIndex = 1),
                  icon: const Icon(Icons.explore_outlined, size: 16),
                  label: const Text('Discover Communities'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.espresso,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    Icon(Icons.checkroom_outlined, color: AppColors.accent, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Shared Closets are Empty',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'No pieces have been shared yet in your circles. Be the first to share a piece from your wardrobe!',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentTabIndex = 2),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Share from My Closet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          )
        else
          // Rich horizontal feed of shared pieces
          SizedBox(
            height: 235,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sharedItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (ctx, idx) {
                final shared = sharedItems[idx];
                final garment = shared.item;
                final currentUserId = context.read<AuthProvider>().user?.id;
                final isOwner = currentUserId != null && currentUserId == shared.ownerId;

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
                          builder: (_) => SharedItemDetailScreen(sharedItem: shared),
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
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          child: Stack(
                            children: [
                              PrivateImageView(
                                imageUrl: garment.imageUrl,
                                height: 115,
                                width: 155,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.espresso.withValues(alpha: 0.8),
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
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        shared.resolvedOwnerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: [
                                  AdaaBrandBadge(text: garment.category.toUpperCase()),
                                  if (garment.primaryColor.isNotEmpty)
                                    Text(
                                      garment.primaryColor,
                                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ],
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

  Widget _buildMetricCard({
    required String title,
    required String count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              count,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.terracottaSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.terracotta, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AnalyzingDialog extends StatelessWidget {
  const _AnalyzingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.terracotta, strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'Analyzing Outfit...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Identifying garments, silhouettes, colors, and extracting candidate pieces...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
