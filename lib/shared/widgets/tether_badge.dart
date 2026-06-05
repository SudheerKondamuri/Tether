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

}}
