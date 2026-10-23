import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/auth_provider.dart';
import '../../home/screens/home_screen.dart';
import '../../splash/screens/splash_screen.dart';
import 'auth_screen.dart';

/// Root Authentication Gate for `adaa`.
/// Enforces the strict rule that NO guest or anonymous user experience exists:
/// - When a valid authenticated session exists: greets the user via the `SplashScreen`
///   before seamlessly transitioning into `HomeScreen`.
/// - When no valid session exists: renders `AuthScreen`.
/// - Never permits unauthenticated access to protected wardrobe or community data.
class AuthGate extends StatefulWidget {
  final bool showSplash;

  const AuthGate({super.key, this.showSplash = true});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _splashCompleted = false;

  bool get _isTestEnvironment {
    if (kIsWeb) return false;
    return const bool.fromEnvironment('FLUTTER_TEST_ENV') ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Show initial splash screen for both authenticated and unauthenticated users on app launch
    if (widget.showSplash && !_isTestEnvironment && !_splashCompleted) {
      return SplashScreen(
        autoNavigate: false,
        displayDuration: const Duration(milliseconds: 1500),
        onComplete: () {
          if (mounted) {
            setState(() => _splashCompleted = true);
          }
        },
      );
    }

    if (auth.isAuthenticated) {
      return const HomeScreen();
    }

    return const AuthScreen();
  }
}
