import 'package:flutter/material.dart';

/// Displays 6 circular dot indicators for the MPIN entry.
/// Filled dots = entered digits, hollow = remaining.
/// Shakes when [shake] triggers.
class MpinDots extends StatefulWidget {
  final int filled;
  final bool hasError;

  const MpinDots({super.key, required this.filled, this.hasError = false});

  @override
  State<MpinDots> createState() => MpinDotsState();
}

class MpinDotsState extends State<MpinDots>
    with SingleTickerProviderStateMixin {
  static const int mpinLength = 6;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  /// Call to trigger the shake + error animation.
  void shake() {
    _shakeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dotColor = widget.hasError ? cs.error : cs.primary;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(mpinLength, (i) {
          final isFilled = i < widget.filled;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? dotColor : Colors.transparent,
              border: Border.all(
                color: isFilled ? dotColor : cs.outline,
                width: 2,
              ),
            ),
          );
        }),
      ),
    );
  }
}
