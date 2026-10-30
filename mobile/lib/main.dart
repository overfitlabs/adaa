import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/session_manager.dart';
import 'core/config/supabase_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/web_responsive_shell.dart';
import 'features/auth/screens/auth_gate.dart';
import 'state/analysis_provider.dart';
import 'state/auth_provider.dart';
import 'state/outfits_provider.dart';
import 'state/tryon_provider.dart';
import 'state/wardrobe_provider.dart';
import 'state/community_provider.dart';
import 'state/profile_provider.dart';
import 'state/notification_provider.dart';
import 'state/stylist_provider.dart';
import 'state/chat_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Attach session expiration handler
  ApiClient.onSessionExpired = () {
    SessionManager.handleSessionExpired();
  };

  // Safely initialize Supabase if configuration is provided
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        publishableKey: SupabaseConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
    } catch (e) {
      debugPrint('Supabase initialization notice: $e');
    }
  }

  runApp(const AdaaApp());
}

/// Root application widget for `adaa`.
class AdaaApp extends StatelessWidget {
  const AdaaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WardrobeProvider()),
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
        ChangeNotifierProvider(create: (_) => TryOnProvider()),
        ChangeNotifierProvider(create: (_) => OutfitsProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => StylistProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'adaa',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: SessionManager.navigatorKey,
        builder: (context, child) => WebResponsiveShell(child: child!),
        home: const AuthGate(),
      ),
    );
  }
}

/// Backwards compatibility alias for tests
typedef WardrobeLensApp = AdaaApp;
