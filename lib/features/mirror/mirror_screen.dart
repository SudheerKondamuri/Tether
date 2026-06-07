import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/tether_card.dart';
import 'package:tether/shared/widgets/v2_locked_button.dart';

/// Screen Mirror placeholder (v1 = ADB scrcpy, v2 = native streaming).
class MirrorScreen extends ConsumerWidget {
  const MirrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: TetherColors.backgroundBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text(
              'Screen Mirror',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: TetherColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── ADB Mode Card ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TetherCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.adb,
                          size: 20, color: TetherColors.accentSecondary),
                      const SizedBox(width: 8),
                      const Text(
                        'ADB + scrcpy Mode',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: TetherColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Screen mirroring uses ADB + scrcpy. Ensure:\n'
                    '  • USB Debugging is enabled on your Android device\n'
                    '  • scrcpy is installed: sudo apt install scrcpy\n'
                    '  • ADB is connected via WiFi or USB',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: TetherColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // ADB status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: TetherColors.surfaceHigher,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: TetherColors.textDisabled,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'ADB: Not connected',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11,
                                color: TetherColors.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── v2 Teaser ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TetherCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Future: Native Streaming',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TetherColors.textDisabled,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'v2 will add native screen streaming via MediaProjection + H.264 encoding, '
                    'removing the scrcpy dependency. Touch input relay and audio '
                    'forwarding are also planned.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: TetherColors.textDisabled,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const V2LockedButton(
                        label: 'Native Stream',
                        icon: Icons.cast,
                      ),
                      const SizedBox(width: 8),
                      const V2LockedButton(
                        label: 'Touch Input',
                        icon: Icons.touch_app_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // ─── Command Reference ───
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TetherColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: TetherColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QUICK COMMANDS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: TetherColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CommandRow(cmd: 'adb connect <ip>:5555'),
                  _CommandRow(cmd: 'adb devices'),
                  _CommandRow(cmd: 'scrcpy --tcpip=<ip>:5555'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  final String cmd;

  const _CommandRow({required this.cmd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Text(
            '\$ ',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: TetherColors.accentSecondary,
            ),
          ),
          Expanded(
            child: SelectableText(
              cmd,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: TetherColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
