import 'package:flutter/material.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/tether_badge.dart';

/// Ghost button with lock icon and "v2" pill — non-interactive.
class V2LockedButton extends StatelessWidget {
  final String label;
  final IconData? icon;

  const V2LockedButton({
    super.key,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'This feature is planned for v2',
      child: MouseRegion(
        cursor: SystemMouseCursors.forbidden,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(TetherRadius.button),
            border: Border.all(color: TetherColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 14,
                color: TetherColors.textDisabled,
              ),
              const SizedBox(width: 6),
              if (icon != null) ...[
                Icon(icon, size: 16, color: TetherColors.textDisabled),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: TetherColors.textDisabled,
                ),
              ),
              const SizedBox(width: 8),
              const TetherBadge(
                label: 'v2',
                color: TetherColors.accentPrimary,
                isSmall: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
