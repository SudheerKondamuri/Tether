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

}}
