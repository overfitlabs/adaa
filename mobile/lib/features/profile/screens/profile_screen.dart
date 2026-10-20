import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaa_brand_badge.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../../state/auth_provider.dart';
import '../../../state/community_provider.dart';
import '../../../state/wardrobe_provider.dart';
import '../../auth/screens/auth_dialog.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback? onNavigateToCloset;
  final VoidCallback? onNavigateToCommunities;

  const ProfileScreen({
    super.key,
    this.onNavigateToCloset,
    this.onNavigateToCommunities,
  });

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to sign out of your adaa account?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.missing),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Successfully signed out of adaa.')),
                );
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showServerSettingsDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiEndpoints.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('API Connection', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Server Endpoint URL:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://127.0.0.1:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                ApiEndpoints.setBaseUrl(newUrl);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('API URL updated to $newUrl')),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wardrobeProv = context.watch<WardrobeProvider>();
    final commProv = context.watch<CommunityProvider>();

    final isAuthenticated = auth.isAuthenticated;
    final displayName = auth.displayName;
    final initials = displayName.isNotEmpty
        ? (displayName.length >= 2 ? displayName.substring(0, 2).toUpperCase() : displayName[0].toUpperCase())
        : 'A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [AppColors.cardShadow],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.accentSoft,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                if (isAuthenticated) ...[
                  Text(
                    auth.user?.email ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const AdaaBrandBadge(text: 'AUTHENTICATED MEMBER'),
                ] else ...[
                  const Text(
                    'Guest Session',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AuthDialog(),
                      );
                    },
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Sign In or Register'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Overview Stats
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onNavigateToCloset,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [AppColors.cardShadow],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 22),
                        const SizedBox(height: 8),
                        Text(
                          '${wardrobeProv.items.length}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'Closet Pieces',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onNavigateToCommunities,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [AppColors.cardShadow],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.groups_outlined, color: AppColors.accent, size: 22),
                        const SizedBox(height: 8),
                        Text(
                          '${commProv.myCommunities.length}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'Active Circles',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Settings Section
          const Text(
            'ACCOUNT & PREFERENCES',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surface,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.router_outlined, color: AppColors.primary),
                  title: const Text('Backend API Server', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(ApiEndpoints.baseUrl, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _showServerSettingsDialog(context),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.shield_outlined, color: AppColors.primary),
                  title: Text('Privacy & Sharing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('Personal wardrobe items are private by default', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
                if (isAuthenticated) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.missing),
                    title: const Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.missing)),
                    onTap: () => _confirmSignOut(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Brand footer
          const Center(
            child: Column(
              children: [
                AdaaWordmark(size: AdaaWordmarkSize.small),
                SizedBox(height: 4),
                Text(
                  'fashion intelligence & campus sharing',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
