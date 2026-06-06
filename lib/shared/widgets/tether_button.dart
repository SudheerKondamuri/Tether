import 'package:flutter/material.dart';
import 'package:tether/shared/theme.dart';

enum TetherButtonVariant { primary, ghost, danger }

/// Multi-variant button component.
class TetherButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final TetherButtonVariant variant;
  final bool isLoading;
  final bool isSmall;

  const TetherButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = TetherButtonVariant.primary,
    this.isLoading = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = isSmall ? 32.0 : 40.0;
    final fontSize = isSmall ? 12.0 : 14.0;
    final bool disabled = onPressed == null;

    switch (variant) {
      case TetherButtonVariant.primary:
        return SizedBox(
          height: height,
          child: ElevatedButton(
            onPressed: disabled || isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: disabled
                  ? TetherColors.surfaceHigher
                  : TetherColors.accentPrimary,
              foregroundColor:
                  disabled ? TetherColors.textDisabled : Colors.white,
              textStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 12 : 20,
              ),
            ),
            child: _buildChild(
              disabled ? TetherColors.textDisabled : Colors.white,
              fontSize,
            ),
          ),
        );

      case TetherButtonVariant.ghost:
        return SizedBox(
          height: height,
          child: OutlinedButton(
            onPressed: disabled || isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: disabled
                  ? TetherColors.textDisabled
                  : TetherColors.textPrimary,
              side: BorderSide(

}}}
