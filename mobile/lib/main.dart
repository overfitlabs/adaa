import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/home/screens/home_screen.dart';
import 'state/analysis_provider.dart';
import 'state/auth_provider.dart';
import 'state/outfits_provider.dart';
import 'state/tryon_provider.dart';
import 'state/wardrobe_provider.dart';
import 'state/community_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      ],
      child: MaterialApp(
        title: 'adaa',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}

/// Backwards compatibility alias for tests
typedef WardrobeLensApp = AdaaApp;
