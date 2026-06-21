import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF252535) : const Color(0xFFE8E8F0);
    final highlight = isDark ? const Color(0xFF353548) : const Color(0xFFF4F4FA);

    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: highlight,
        );
  }
}

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const ShimmerBox(height: 14, width: 180),
        const SizedBox(height: 12),
        const ShimmerBox(height: 40),
        const SizedBox(height: 16),
        const ShimmerBox(height: 160, borderRadius: AppRadius.card),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: List.generate(
            4,
            (_) => const ShimmerBox(height: 100, borderRadius: AppRadius.card),
          ),
        ),
        const SizedBox(height: 16),
        const ShimmerBox(height: 220, borderRadius: AppRadius.card),
      ],
    );
  }
}

class TodayHeroShimmer extends StatelessWidget {
  const TodayHeroShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: ShimmerBox(height: 100, borderRadius: AppRadius.card),
    );
  }
}
