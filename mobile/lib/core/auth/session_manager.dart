import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/screens/logout_success_screen.dart';
import '../../state/analysis_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/community_provider.dart';
import '../../state/outfits_provider.dart';
import '../../state/tryon_provider.dart';
import '../../state/wardrobe_provider.dart';
import '../../state/profile_provider.dart';
import '../../state/notification_provider.dart';
import '../../state/stylist_provider.dart';
import '../network/api_client.dart';

/// Centralized session manager for `adaa`.
/// Enforces complete session isolation, state destruction on logout,
/// and safe redirection when sessions expire or accounts switch.
class SessionManager {
  /// Global navigator key allowing out-of-band expiration redirects
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Completely clears all user-specific state across all providers and local image caches.
  /// Prevents any data leakage between user sessions, on logout, or across account switching.
  static void clearAllUserData(BuildContext context) {
    try {
      context.read<WardrobeProvider>().clear();
    } catch (_) {}
    try {
      context.read<CommunityProvider>().clear();
    } catch (_) {}
    try {
      context.read<AnalysisProvider>().clear();
    } catch (_) {}
    try {
      context.read<OutfitsProvider>().clear();
    } catch (_) {}
    try {
      context.read<TryOnProvider>().clear();
    } catch (_) {}
    try {
      context.read<ProfileProvider>().clear();
    } catch (_) {}
    try {
      context.read<NotificationProvider>().clear();
    } catch (_) {}
    try {
      context.read<StylistProvider>().clear();
    } catch (_) {}

    ApiClient.authToken = null;

    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
  }

  /// Performs a complete, secure logout:
  /// 1. Clears all user-specific provider caches and image caches.
  /// 2. Invalidate the active authentication session and tokens.
  /// 3. Purges protected screens from navigation history (`(route) => false`).
  /// 4. Displays the dedicated `LogoutSuccessScreen`.
  static Future<void> performLogout(BuildContext context) async {
    clearAllUserData(context);
    try {
      await context.read<AuthProvider>().signOut();
    } catch (e) {
      debugPrint('Logout sign-out warning: $e');
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LogoutSuccessScreen()),
        (route) => false,
      );
    }
  }

  /// Triggered automatically when an active session expires (e.g. backend returns 401).
  /// Purges cached data and safely routes to the sign-in screen.
  static void handleSessionExpired([BuildContext? context]) {
    final ctx = context ?? navigatorKey.currentContext;
    if (ctx != null) {
      clearAllUserData(ctx);
      try {
        ctx.read<AuthProvider>().signOut();
      } catch (_) {}
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        const SnackBar(
          content: Text('Your session has expired. Please sign in again.'),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }
}
