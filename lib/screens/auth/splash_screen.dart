import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../home_screen.dart';
import 'phone_entry_screen.dart';

/// Reads AuthStatus and routes to the correct screen.
/// Shown only at cold-start while Firebase resolves the session.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<app_auth.AuthProvider, app_auth.AuthStatus>(
      selector: (_, p) => p.status,
      builder: (context, status, _) {
        switch (status) {
          case app_auth.AuthStatus.authenticated:
            // Use addPostFrameCallback so we never navigate mid-build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            });
            return _SplashView();

          case app_auth.AuthStatus.unauthenticated:
          case app_auth.AuthStatus.error:
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
              );
            });
            return _SplashView();

          case app_auth.AuthStatus.initial:
          case app_auth.AuthStatus.loading:
            return _SplashView();
        }
      },
    );
  }
}

class _SplashView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: primary,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'MicroFinance',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
