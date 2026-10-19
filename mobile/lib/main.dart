import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/home/screens/home_screen.dart';
import 'state/analysis_provider.dart';
import 'state/outfits_provider.dart';
import 'state/tryon_provider.dart';
import 'state/wardrobe_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WardrobeLensApp());
}

class WardrobeLensApp extends StatelessWidget {
  const WardrobeLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WardrobeProvider()),
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
        ChangeNotifierProvider(create: (_) => TryOnProvider()),
        ChangeNotifierProvider(create: (_) => OutfitsProvider()),
      ],
      child: MaterialApp(
        title: 'WardrobeLens',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
