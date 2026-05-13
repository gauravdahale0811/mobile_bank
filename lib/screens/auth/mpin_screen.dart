import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../widgets/auth/mpin_dots.dart';
import '../../widgets/auth/num_pad.dart';
import '../home_screen.dart';

/// MPIN entry screen used for both login and registration.
///
/// Login flow   : user enters 6-digit MPIN → auto-submits.
/// Register flow: user enters MPIN → confirms MPIN → auto-submits.
class MpinScreen extends StatefulWidget {
  final String phone;
  final bool isRegister;

  const MpinScreen({
    super.key,
    required this.phone,
    this.isRegister = false,
  });

  @override
  State<MpinScreen> createState() => _MpinScreenState();
}

enum _Step { enter, confirm }

class _MpinScreenState extends State<MpinScreen> {
  static const int _mpinLength = 6;

  final _dotsKey = GlobalKey<MpinDotsState>();

  _Step _step = _Step.enter;
  String _entered = '';
  String _firstPin = '';
  bool _hasError = false;

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _maskedPhone {
    final p = widget.phone;
    if (p.length < 6) return '+91 $p';
    return '+91 ${p.substring(0, 2)}XXXXXX${p.substring(p.length - 2)}';
  }

  String get _title {
    if (widget.isRegister) {
      return _step == _Step.enter ? 'Set your MPIN' : 'Confirm MPIN';
    }
    return 'Enter your MPIN';
  }

  String get _subtitle {
    if (widget.isRegister) {
      return _step == _Step.enter
          ? 'Choose a 6-digit MPIN to secure your account'
          : 'Re-enter your MPIN to confirm';
    }
    return 'Use your 6-digit MPIN to login';
  }

  // ── Input handling ─────────────────────────────────────────────────────────

  void _onDigit(String digit) {
    if (_entered.length >= _mpinLength) return;
    setState(() {
      _entered += digit;
      _hasError = false;
    });
    if (_entered.length == _mpinLength) _onComplete();
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _hasError = false;
    });
  }

  Future<void> _onComplete() async {
    if (widget.isRegister && _step == _Step.enter) {
      // Store first entry and move to confirm step.
      await Future.delayed(const Duration(milliseconds: 120));
      setState(() {
        _firstPin = _entered;
        _entered = '';
        _step = _Step.confirm;
      });
      return;
    }

    if (widget.isRegister && _step == _Step.confirm) {
      if (_entered != _firstPin) {
        _shakeError('MPINs do not match. Try again.');
        return;
      }
    }

    // Small delay so the last dot fills visually before auth starts.
    await Future.delayed(const Duration(milliseconds: 120));
    _submit();
  }

  Future<void> _submit() async {
    final provider = context.read<app_auth.AuthProvider>();
    final pin = _entered;

    bool success;
    if (widget.isRegister) {
      success = await provider.register(widget.phone, pin);
    } else {
      success = await provider.signIn(widget.phone, pin);
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      final msg = provider.errorMessage ?? 'Incorrect MPIN.';
      _shakeError(msg);
    }
  }

  void _shakeError(String message) {
    setState(() {
      _entered = '';
      _hasError = true;
      if (widget.isRegister && _step == _Step.confirm) {
        // Go back to set step on mismatch.
        _step = _Step.enter;
        _firstPin = '';
      }
    });
    _dotsKey.currentState?.shake();
    _showSnack(message);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 2),
      ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoading = context.select<app_auth.AuthProvider, bool>(
      (p) => p.status == app_auth.AuthStatus.loading,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // ── Brand icon ─────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.lock_outline_rounded,
                      size: 34, color: cs.primary),
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ──────────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _title,
                  key: ValueKey(_title),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                _maskedPhone,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
              ),

              const SizedBox(height: 36),

              // ── Dot indicator ──────────────────────────────────────────────
              MpinDots(
                key: _dotsKey,
                filled: _entered.length,
                hasError: _hasError,
              ),

              const SizedBox(height: 12),

              // ── Loading indicator ──────────────────────────────────────────
              SizedBox(
                height: 4,
                child: isLoading
                    ? LinearProgressIndicator(
                        borderRadius: BorderRadius.circular(2),
                        color: cs.primary,
                      )
                    : null,
              ),

              const Spacer(),

              // ── Numpad ─────────────────────────────────────────────────────
              NumPad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                enabled: !isLoading,
              ),

              const SizedBox(height: 20),

              // ── Forgot MPIN (login only) ───────────────────────────────────
              if (!widget.isRegister)
                Center(
                  child: TextButton(
                    onPressed: () => _showForgotMpinSheet(context),
                    child: const Text('Forgot MPIN?'),
                  ),
                ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showForgotMpinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ForgotMpinSheet(phone: widget.phone),
    );
  }
}

// ── Forgot MPIN bottom sheet ──────────────────────────────────────────────────

class _ForgotMpinSheet extends StatefulWidget {
  final String phone;
  const _ForgotMpinSheet({required this.phone});

  @override
  State<_ForgotMpinSheet> createState() => _ForgotMpinSheetState();
}

class _ForgotMpinSheetState extends State<_ForgotMpinSheet> {
  bool _sent = false;
  bool _loading = false;
  String? _error;

  Future<void> _sendReset() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final provider = context.read<app_auth.AuthProvider>();
    final ok = await provider.sendMpinReset(widget.phone);

    if (!mounted) return;
    if (ok) {
      setState(() => _sent = true);
    } else {
      setState(() => _error = provider.errorMessage);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final maskedPhone =
        '+91 ${widget.phone.substring(0, 2)}XXXXXX${widget.phone.substring(widget.phone.length - 2)}';

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _sent ? Icons.mark_email_read_outlined : Icons.lock_reset,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _sent ? 'Reset Link Sent' : 'Forgot MPIN?',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _sent
                ? 'A password reset link has been sent to the email linked to $maskedPhone. '
                  'Follow the link to set a new MPIN, then log in again.'
                : 'We will send a reset link to the email registered for $maskedPhone.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          if (_sent)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _sendReset,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send Reset Link'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
