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
            isActive: selectedIndex == 2,
            onTap: () => ref.read(selectedNavProvider.notifier).state = 2,
          ),
          _NavItem(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            index: 3,
            isActive: selectedIndex == 3,
            badgeCount: 0,
            onTap: () => ref.read(selectedNavProvider.notifier).state = 3,
          ),
          _NavItem(
            icon: Icons.monitor_outlined,
            label: 'Screen Mirror',
            index: 4,
            isActive: selectedIndex == 4,
            onTap: () => ref.read(selectedNavProvider.notifier).state = 4,
          ),

          const Spacer(),

          // ─── Settings (pinned to bottom) ───
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            index: 5,
            isActive: selectedIndex == 5,
            onTap: () => ref.read(selectedNavProvider.notifier).state = 5,
          ),

          // ─── Footer ───
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'v${TetherConstants.appVersion}',
                  style: TetherTheme.monoSmall,
                ),
                const SizedBox(height: 2),
                const Text(
                  'v2 features locked',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: TetherColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ConnectionStatus _mapStatus(TetherConnectionState state) {
    switch (state) {
      case TetherConnectionState.connected:
        return ConnectionStatus.connected;
      case TetherConnectionState.connecting:
      case TetherConnectionState.searching:
        return ConnectionStatus.searching;
      case TetherConnectionState.disconnected:
        return ConnectionStatus.disconnected;
    }
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool isActive;
  final int? badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.isActive,
    this.badgeCount,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          decoration: BoxDecoration(
            color: isActive || _hovering
                ? TetherColors.surfaceElevated
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isActive
                    ? TetherColors.accentPrimary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: 12, right: 12),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: isActive
                    ? TetherColors.textPrimary
                    : TetherColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? TetherColors.textPrimary
                        : TetherColors.textSecondary,
                  ),
                ),
              ),
              if (widget.badgeCount != null && widget.badgeCount! > 0)
                TetherCountBadge(count: widget.badgeCount!),
            ],
          ),
        ),
      ),
    );
  }
}
