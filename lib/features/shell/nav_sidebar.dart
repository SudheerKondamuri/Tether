import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/widgets/status_indicator.dart';
import 'package:tether/shared/widgets/tether_badge.dart';
import 'package:tether/features/shell/linux_shell.dart';
import 'package:tether/core/networking/connection_manager.dart';

/// Left navigation sidebar (200px) with device card and nav items.
class NavSidebar extends ConsumerWidget {
  const NavSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavProvider);
    final connectionAsync = ref.watch(connectionStateProvider);
    final deviceAsync = ref.watch(connectedDeviceProvider);

    final connState = connectionAsync.valueOrNull ?? TetherConnectionState.disconnected;
    final connDevice = deviceAsync.valueOrNull;
    final isConnected = connState == TetherConnectionState.connected;

    return Container(
      width: 200,
      color: TetherColors.backgroundBase,
      child: Column(
        children: [
          // ─── Device Card ───
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TetherColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isConnected
                      ? TetherColors.accentSecondary.withAlpha(80)
                      : TetherColors.borderSubtle,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isConnected
                                ? TetherColors.accentSecondary.withAlpha(100)
                                : TetherColors.borderSubtle,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isConnected ? Icons.phone_android : Icons.devices,
                          size: 18,
                          color: isConnected
                              ? TetherColors.accentSecondary
                              : TetherColors.textDisabled,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected
                                  ? connDevice?.name ?? 'Connected'
                                  : 'No Device',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: TetherColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            StatusIndicator(
                              status: _mapStatus(connState),
                              size: 6,
                              showLabel: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.battery_std,
                          size: 12, color: TetherColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        connDevice?.battery != null
                            ? '${connDevice!.battery}%'
                            : '--%',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: TetherColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.wifi,
                          size: 12, color: TetherColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        connDevice?.wifiStrength != null
                            ? '${connDevice!.wifiStrength}%'
                            : '--',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: TetherColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Navigation Items ───
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            index: 0,
            isActive: selectedIndex == 0,
            onTap: () => ref.read(selectedNavProvider.notifier).state = 0,
          ),
          _NavItem(
            icon: Icons.content_paste_outlined,
            label: 'Clipboard',
            index: 1,
            isActive: selectedIndex == 1,
            badgeCount: 0,
            onTap: () => ref.read(selectedNavProvider.notifier).state = 1,
          ),
          _NavItem(
            icon: Icons.folder_outlined,
            label: 'Files',
            index: 2,

}}
