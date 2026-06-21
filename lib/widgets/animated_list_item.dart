import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;

    return Animate(
      effects: [
        FadeEffect(duration: 350.ms, curve: Curves.easeOutCubic),
        SlideEffect(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        ),
      ],
      delay: Duration(milliseconds: index * 40),
      child: child,
    );
  }
}
