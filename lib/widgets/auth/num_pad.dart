import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Phone-dialer-style numpad used for MPIN entry.
/// Layout:
///   1  2  3
///   4  5  6
///   7  8  9
///      0  ⌫
class NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  const NumPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(context, ['1', '2', '3']),
        const SizedBox(height: 12),
        _row(context, ['4', '5', '6']),
        const SizedBox(height: 12),
        _row(context, ['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Blank spacer cell
            const SizedBox(width: 80, height: 70),
            const SizedBox(width: 16),
            _DigitKey(
              label: '0',
              onTap: enabled ? () => _onDigit('0') : null,
            ),
            const SizedBox(width: 16),
            _BackspaceKey(
              onTap: enabled ? onBackspace : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.asMap().entries.map((e) {
        return Row(
          children: [
            if (e.key > 0) const SizedBox(width: 16),
            _DigitKey(
              label: e.value,
              onTap: enabled ? () => _onDigit(e.value) : null,
            ),
          ],
        );
      }).toList(),
    );
  }

  void _onDigit(String d) {
    HapticFeedback.lightImpact();
    onDigit(d);
  }
}

class _DigitKey extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _DigitKey({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 80,
      height: 70,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          splashColor: cs.primary.withValues(alpha: 0.2),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: onTap == null ? cs.outline : cs.onSurface,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final VoidCallback? onTap;

  const _BackspaceKey({this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 80,
      height: 70,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(40),
          splashColor: cs.error.withValues(alpha: 0.15),
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              size: 26,
              color: onTap == null ? cs.outline : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
