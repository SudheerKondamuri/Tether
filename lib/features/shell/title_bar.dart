import 'package:flutter/material.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/features/pairing/pairing_dialog.dart';
import 'package:tether/shared/constants.dart';

/// Custom title bar for the Linux desktop app (40px).
class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: TetherColors.backgroundBase,
        border: Border(
          bottom: BorderSide(color: TetherColors.borderSubtle, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ─── App Logo + Name ───
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: TetherColors.accentPrimary,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Tether',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TetherColors.textPrimary,
            ),
          ),

          const SizedBox(width: 16),

          // ─── Pair Device Button ───
          _WindowButton(
            icon: Icons.devices,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const PairingDialog(
                  port: TetherConstants.tcpPort,
                ),
              );
            },
          ),

          const Spacer(),

          // ─── Window Controls ───
          _WindowButton(
            icon: Icons.remove,
            onTap: () {},
          ),
          const SizedBox(width: 4),
          _WindowButton(
            icon: Icons.crop_square,
            onTap: () {},
          ),
          const SizedBox(width: 4),
          _WindowButton(
            icon: Icons.close,
            onTap: () {},
            hoverColor: TetherColors.accentDanger,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _hovering
                ? (widget.hoverColor?.withAlpha(40) ??
                    TetherColors.surfaceHigher)
                : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: _hovering
                ? (widget.hoverColor ?? TetherColors.textPrimary)
                : TetherColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
