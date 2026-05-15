import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../widgets/auth/mpin_dots.dart';
import '../widgets/auth/num_pad.dart';
import 'auth/phone_entry_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth.AuthProvider>();
    final phone = authProvider.phone ?? '—';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Account ────────────────────────────────────────────────────────
          _sectionHeader(context, 'Account'),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text('+91 $phone'),
            subtitle: const Text('Logged in as'),
          ),
          const Divider(indent: 16, endIndent: 16),

          // ── Security ───────────────────────────────────────────────────────
          _sectionHeader(context, 'Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change MPIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _ChangeMpinScreen()),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),

          // ── Logout ─────────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<app_auth.AuthProvider>().signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
        (_) => false,
      );
    }
  }
}

// ── Change MPIN sub-screen ───────────────────────────────────────────────────

enum _ChangeMpinStep { current, newPin, confirm }

class _ChangeMpinScreen extends StatefulWidget {
  const _ChangeMpinScreen();

  @override
  State<_ChangeMpinScreen> createState() => _ChangeMpinScreenState();
}

class _ChangeMpinScreenState extends State<_ChangeMpinScreen> {
  static const int _len = 6;

  final _dotsKey = GlobalKey<MpinDotsState>();
  _ChangeMpinStep _step = _ChangeMpinStep.current;
  String _entered = '';
  String _currentPin = '';
  String _newPin = '';
  bool _hasError = false;

  String get _title {
    switch (_step) {
      case _ChangeMpinStep.current:
        return 'Enter Current MPIN';
      case _ChangeMpinStep.newPin:
        return 'Enter New MPIN';
      case _ChangeMpinStep.confirm:
        return 'Confirm New MPIN';
    }
  }

  void _onDigit(String d) {
    if (_entered.length >= _len) return;
    setState(() {
      _entered += d;
      _hasError = false;
    });
    if (_entered.length == _len) _onComplete();
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _hasError = false;
    });
  }

  Future<void> _onComplete() async {
    await Future.delayed(const Duration(milliseconds: 120));

    switch (_step) {
      case _ChangeMpinStep.current:
        setState(() {
          _currentPin = _entered;
          _entered = '';
          _step = _ChangeMpinStep.newPin;
        });

      case _ChangeMpinStep.newPin:
        if (_entered == _currentPin) {
          _shakeError('New MPIN cannot be same as current.');
          return;
        }
        setState(() {
          _newPin = _entered;
          _entered = '';
          _step = _ChangeMpinStep.confirm;
        });

      case _ChangeMpinStep.confirm:
        if (_entered != _newPin) {
          _shakeError('MPINs do not match. Start over.');
          setState(() {
            _step = _ChangeMpinStep.newPin;
            _newPin = '';
          });
          return;
        }
        _submit();
    }
  }

  Future<void> _submit() async {
    final provider = context.read<app_auth.AuthProvider>();
    final success = await provider.changeMpin(_currentPin, _entered);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MPIN changed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _shakeError(provider.errorMessage ?? 'Incorrect current MPIN.');
      setState(() {
        _step = _ChangeMpinStep.current;
        _currentPin = '';
        _newPin = '';
      });
    }
  }

  void _shakeError(String msg) {
    setState(() {
      _entered = '';
      _hasError = true;
    });
    _dotsKey.currentState?.shake();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<app_auth.AuthProvider, bool>(
      (p) => p.status == app_auth.AuthStatus.loading,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change MPIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _title,
                  key: ValueKey(_title),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 40),
              MpinDots(
                key: _dotsKey,
                filled: _entered.length,
                hasError: _hasError,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 4,
                child: isLoading
                    ? const LinearProgressIndicator()
                    : null,
              ),
              const Spacer(),
              NumPad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                enabled: !isLoading,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
