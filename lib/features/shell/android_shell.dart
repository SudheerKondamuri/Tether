import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/status_indicator.dart';
import 'package:tether/features/clipboard/clipboard_screen.dart';
import 'package:tether/features/files/files_screen.dart';
import 'package:tether/features/settings/settings_screen.dart';
import 'package:tether/features/pairing/pairing_dialog.dart';
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/shared/widgets/disconnected_overlay.dart';

/// Android bottom-navigation shell.
class AndroidShell extends ConsumerStatefulWidget {
  const AndroidShell({super.key});

  @override
  ConsumerState<AndroidShell> createState() => _AndroidShellState();
}

class _AndroidShellState extends ConsumerState<AndroidShell> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(connectionStateProvider);
    final connState = connectionAsync.valueOrNull ?? TetherConnectionState.disconnected;
    final isConnected = connState == TetherConnectionState.connected;

    return Scaffold(
      backgroundColor: TetherColors.backgroundBase,
      body: IndexedStack(
        index: _currentTab,
        children: [
          const _AndroidHome(),
          isConnected
              ? const ClipboardScreen()
              : DisconnectedOverlay(
                  featureName: 'Clipboard History',
                  actionLabel: 'Pair Device',
                  onAction: () {
                    showDialog(
                      context: context,
                      builder: (_) => const PairingScanDialog(),
                    );
                  },
                ),
          isConnected
              ? const FilesScreen()
              : DisconnectedOverlay(
                  featureName: 'Shared Files',
                  actionLabel: 'Pair Device',
                  onAction: () {
                    showDialog(
                      context: context,
                      builder: (_) => const PairingScanDialog(),
                    );
                  },
                ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: TetherColors.borderSubtle, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.content_paste_outlined),
              activeIcon: Icon(Icons.content_paste),
              label: 'Clipboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder),
              label: 'Files',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

/// Android home screen with connection card, module pills, activity feed.
class _AndroidHome extends ConsumerWidget {
  const _AndroidHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStateProvider);
    final deviceAsync = ref.watch(connectedDeviceProvider);

    final connState = connectionAsync.valueOrNull ?? TetherConnectionState.disconnected;
    final connDevice = deviceAsync.valueOrNull;

    final isConnected = connState == TetherConnectionState.connected;
    final statusLabel = connDevice?.name ?? _stateLabel(connState);
    final statusDetail = isConnected
        ? '${connDevice?.ip ?? '?'}:${connDevice?.port ?? '?'}'
        : _stateDetail(connState);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ─── Header ───
          Row(
            children: [
              const Text(
                'Tether',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: TetherColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, size: 22),
                color: TetherColors.textSecondary,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const PairingScanDialog(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Connection Card ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TetherColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isConnected
                    ? TetherColors.accentSecondary.withAlpha(80)
                    : TetherColors.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                StatusIndicator(
                  status: _mapStatus(connState),
                  size: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: TetherColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusDetail,
                        style: TetherTheme.monoSmall.copyWith(
                          color: TetherColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (connDevice?.battery != null)
                  _BatteryChip(battery: connDevice!.battery!),
                if (isConnected) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                    icon: const Icon(
                      Icons.link_off,
                      color: TetherColors.accentDanger,
                      size: 20,
                    ),
                    onPressed: () => ref.read(connectionManagerProvider).disconnect(),
                    tooltip: 'Disconnect',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Active Modules ───
          Text(
            'ACTIVE MODULES',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ModulePill(
                  icon: Icons.content_paste,
                  label: 'Clipboard',
                  isActive: true,
                ),
                const SizedBox(width: 8),
                _ModulePill(
                  icon: Icons.notifications,
                  label: 'Notifications',
                  isActive: true,
                ),
                const SizedBox(width: 8),
                _ModulePill(
                  icon: Icons.folder,
                  label: 'Files',
                  isActive: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Recent Activity ───
          Text(
            'RECENT ACTIVITY',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _ActivityItem(
            icon: Icons.content_paste,
            iconColor: TetherColors.accentPrimary,
            text: 'No activity yet',
            time: '--:--',
          ),
        ],
      ),
    );
  }

  String _stateLabel(TetherConnectionState state) {
    switch (state) {
      case TetherConnectionState.connected:
        return 'Connected';
      case TetherConnectionState.connecting:
        return 'Connecting...';
      case TetherConnectionState.searching:
        return 'Searching...';
      case TetherConnectionState.disconnected:
        return 'No device connected';
    }
  }

  String _stateDetail(TetherConnectionState state) {
    switch (state) {
      case TetherConnectionState.searching:
        return 'Scanning local network...';
      case TetherConnectionState.connecting:
        return 'Establishing TLS handshake...';
      case TetherConnectionState.disconnected:
        return 'Tap QR icon to pair';
      case TetherConnectionState.connected:
        return '';
    }
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

class _BatteryChip extends StatelessWidget {
  final int battery;
  const _BatteryChip({required this.battery});

  @override
  Widget build(BuildContext context) {
    final color = battery > 20
        ? TetherColors.accentSecondary
        : TetherColors.accentDanger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            battery > 80
                ? Icons.battery_full
                : battery > 20
                    ? Icons.battery_3_bar
                    : Icons.battery_alert,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$battery%',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModulePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _ModulePill({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TetherColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? TetherColors.accentSecondary.withAlpha(80)
              : TetherColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14,
              color: isActive
                  ? TetherColors.accentSecondary
                  : TetherColors.textDisabled),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive
                  ? TetherColors.textPrimary
                  : TetherColors.textDisabled,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'ON' : 'OFF',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? TetherColors.accentSecondary
                  : TetherColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: TetherColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TetherColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: TetherColors.textSecondary,
              ),
            ),
          ),
          Text(
            time,
            style: TetherTheme.monoSmall,
          ),
        ],
      ),
    );
  }
}
