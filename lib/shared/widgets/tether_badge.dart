import 'package:flutter/material.dart';
import 'package:tether/shared/theme.dart';

/// Small colored badge/pill for data type labels, status tags, etc.
class TetherBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final bool isSmall;

  const TetherBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(TetherRadius.badge),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: isSmall ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: textColor ?? color,
        ),
      ),
    );
  }
}

/// Circular count badge for navigation item notification counts.
class TetherCountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const TetherCountBadge({
    super.key,
    required this.count,
    this.color = TetherColors.accentPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    final display = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        display,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
