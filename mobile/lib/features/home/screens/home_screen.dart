import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/analysis_provider.dart';
import '../../../state/wardrobe_provider.dart';
import '../../../state/outfits_provider.dart';
import '../../../state/auth_provider.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../analysis/screens/analysis_detail_screen.dart';
import '../../auth/screens/auth_dialog.dart';
import '../../wardrobe/screens/wardrobe_screen.dart';
import '../../tryon/screens/tryon_screen.dart';
import '../../outfits/screens/outfits_screen.dart';
import '../../styling/screens/recommendations_screen.dart';

import '../../../state/community_provider.dart';
import '../../communities/screens/communities_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
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
      }
    }
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (!mounted) return;

      await _runAnalysis(picked);
    } catch (e) {
      if (mounted) {
        _showAnalysisErrorDialog('Failed to pick image: $e');
      }
    }
  }

  Future<void> _runAnalysis(XFile file) async {
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

      if (success && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AnalysisDetailScreen(),
          ),
        );
      } else if (mounted) {
        _showAnalysisErrorDialog(analysisProv.error ?? 'Failed to analyze outfit image.');
      }
    } catch (e) {
      if (mounted && !dialogPopped) {
        dialogPopped = true;
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        _showAnalysisErrorDialog('Analysis error: $e');
      }
    } finally {
      if (mounted && !dialogPopped) {
        dialogPopped = true;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _showAnalysisErrorDialog(String errorMessage) {
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
                _runAnalysis(lastFile);
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
                    'Specify the FastAPI backend server URL for WardrobeLens.',
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

  void _showImageSourceModal() {
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
              const Text(
                'Upload Outfit Inspiration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a photo featuring a person, flat-lay garments, or individual pieces.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                  _pickAndAnalyzeImage(ImageSource.gallery);
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
                  _pickAndAnalyzeImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    final outfits = context.watch<OutfitsProvider>();
    final analysisProv = context.watch<AnalysisProvider>();
    final communityProv = context.watch<CommunityProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'WARDROBE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'LENS',
              style: TextStyle(
                fontWeight: FontWeight.w300,
                fontSize: 18,
                letterSpacing: 2.0,
                color: AppColors.primary,
              ),
            ),
          ],
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
                        auth.signOut();
                      }
                    },
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton.icon(
                  icon: const Icon(Icons.person_outline, size: 16),
                  label: const Text('Sign In', style: TextStyle(fontSize: 12)),
                  onPressed: () => AuthDialog.show(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
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
      ),
      body: RefreshIndicator(
        onRefresh: _checkHealthAndLoadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Inspiration Card
              _buildInspirationHero(),

              const SizedBox(height: 24),

              // Quick Overview Counters
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Wardrobe',
                      count: '${wardrobe.items.length}',
                      icon: Icons.checkroom_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WardrobeScreen()),
                      ),
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CommunitiesScreen()),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WardrobeScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _buildFeatureTile(
                title: 'Communities & Shared Closets',
                subtitle: 'Explore student style circles and browse shared wardrobes',
                icon: Icons.groups_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommunitiesScreen()),
                ),
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
      ),
    );
  }

  Widget _buildInspirationHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 18,
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
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'AI OUTFIT INTELLIGENCE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Decode Any Outfit.\nMatch Your Closet.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload a photo from Pinterest, Instagram, or a flat-lay to break down every piece and find matches in your wardrobe.',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showImageSourceModal,
              icon: const Icon(Icons.arrow_upward_rounded, size: 18, color: AppColors.primary),
              label: const Text(
                'Upload Outfit Photo',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
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
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
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
            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'Analyzing Outfit...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Identifying garments, silhouettes, colors, and styling attributes...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
