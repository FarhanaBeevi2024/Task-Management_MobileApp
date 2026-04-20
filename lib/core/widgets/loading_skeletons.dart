import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shared shimmer base for loading placeholders.
class LoadingSkeletons {
  LoadingSkeletons._();

  static Widget _bone(
    BuildContext context, {
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }

  static Widget shimmerWrap(BuildContext context, {required Widget child}) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer.fromColors(
      baseColor: base.withOpacity(0.45),
      highlightColor: base.withOpacity(0.15),
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }

  /// Placeholder list for the projects tab.
  ///
  /// [bottomScrollPadding] matches the main list when the shell uses
  /// `extendBody` and a floating bottom bar (pad to match the real list).
  static Widget projectList(
    BuildContext context, {
    int itemCount = 8,
    double bottomScrollPadding = 24,
  }) {
    return shimmerWrap(
      context,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomScrollPadding),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, __) => _bone(
          ctx,
          width: double.infinity,
          height: 72,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Horizontal Kanban columns with stacked card bones.
  static Widget kanbanBoard(
    BuildContext context, {
    int columnCount = 4,
    double columnWidth = 292,
  }) {
    return shimmerWrap(
      context,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        itemCount: columnCount,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (ctx, __) {
          return SizedBox(
            width: columnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bone(ctx, width: 120, height: 14, borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          _cardBone(ctx),
                          const SizedBox(height: 10),
                          _cardBone(ctx, short: true),
                          const SizedBox(height: 10),
                          _cardBone(ctx),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _cardBone(BuildContext context, {bool short = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bone(context, width: 72, height: 10, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 8),
        _bone(
          context,
          width: double.infinity,
          height: short ? 36 : 48,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }
}
