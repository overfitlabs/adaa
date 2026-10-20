import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/auth_provider.dart';
import '../../home/screens/home_screen.dart';
import 'auth_screen.dart';

/// Root Authentication Gate for `adaa`.
/// Enforces the strict rule that NO guest or anonymous user experience exists.
/// - When a valid authenticated session exists: renders `HomeScreen`.
/// - When no valid session exists: renders `AuthScreen`.
/// - Never permits unauthenticated access to protected wardrobe or community data.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // If active confirmed session is present, show protected home experience
    if (auth.isAuthenticated) {
      return const HomeScreen();
    }

    // Otherwise show strictly login / signup screen
    return const AuthScreen();
  }
}
