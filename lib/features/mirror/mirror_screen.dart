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

}}
