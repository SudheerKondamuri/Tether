import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/status_indicator.dart';
import 'package:tether/features/clipboard/clipboard_screen.dart';
import 'package:tether/features/files/files_screen.dart';
import 'package:tether/features/settings/settings_screen.dart';
import 'package:tether/features/pairing/pairing_dialog.dart';
import 'package:tether/core/networking/connection_manager.dart';

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
    return Scaffold(
      backgroundColor: TetherColors.backgroundBase,
      body: IndexedStack(
        index: _currentTab,
        children: const [
          _AndroidHome(),
          ClipboardScreen(),
          FilesScreen(),
          SettingsScreen(),
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

}}
