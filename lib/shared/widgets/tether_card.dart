import 'package:flutter/material.dart';
import 'package:tether/shared/theme.dart';

/// Elevated card with the Tether design language.
class TetherCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final bool isSelected;

  const TetherCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = isSelected
        ? TetherColors.accentPrimary.withAlpha(120)
        : (borderColor ?? TetherColors.borderSubtle);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: TetherColors.surfaceElevated,
        borderRadius: BorderRadius.circular(TetherRadius.card),
        border: Border.all(color: border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(TetherRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TetherRadius.card),
          hoverColor: TetherColors.surfaceHigher,
          splashColor: TetherColors.accentPrimary.withAlpha(20),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
