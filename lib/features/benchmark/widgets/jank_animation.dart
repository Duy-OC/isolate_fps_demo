import 'package:flutter/material.dart';

/// Continuous animation (spinner + bouncing ball).
///
/// It MUST keep running during the benchmark: without scheduled frames the
/// engine has no ticks and FPS would read 0 instead of showing the freeze.
class JankAnimation extends StatefulWidget {
  const JankAnimation({super.key});

  @override
  State<JankAnimation> createState() => _JankAnimationState();
}

class _JankAnimationState extends State<JankAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _spin.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _spin,
            child: Icon(Icons.refresh, size: 36, color: color),
          ),
          const SizedBox(width: 24),
          AnimatedBuilder(
            animation: _bounce,
            builder: (context, _) => Transform.translate(
              offset: Offset(0, -16 * _bounce.value),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              value: _bounce.value,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}
