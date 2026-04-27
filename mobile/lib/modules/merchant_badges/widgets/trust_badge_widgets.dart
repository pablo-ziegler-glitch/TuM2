import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/trust_badges.dart';

class TrustBadgeChip extends StatelessWidget {
  const TrustBadgeChip({
    super.key,
    required this.badge,
    this.compact = true,
  });

  final TrustBadgeId badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EEF9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        trustBadgeLabel(badge),
        style: TextStyle(
          color: AppColors.primary700,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class TrustBadgeRow extends StatelessWidget {
  const TrustBadgeRow({
    super.key,
    required this.badges,
    required this.maxVisible,
    this.compact = true,
  });

  final List<TrustBadgeId> badges;
  final int maxVisible;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty || maxVisible <= 0) return const SizedBox.shrink();
    final visible = badges.take(maxVisible).toList(growable: false);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: visible
          .map((badge) => TrustBadgeChip(badge: badge, compact: compact))
          .toList(growable: false),
    );
  }
}
