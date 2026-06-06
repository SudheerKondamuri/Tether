import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/status_indicator.dart';
import 'package:tether/core/networking/connection_manager.dart';

/// Bottom status bar showing live connection state, IP, latency (28px).
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStateProvider);
    final deviceAsync = ref.watch(connectedDeviceProvider);

    final connState = connectionAsync.valueOrNull ?? TetherConnectionState.disconnected;
    final connDevice = deviceAsync.valueOrNull;

    final isConnected = connState == TetherConnectionState.connected;
    final ipLabel = isConnected
        ? '${connDevice?.ip ?? '?'}:${connDevice?.port ?? '?'}'
        : '---.---.---.---:5280';

    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: TetherColors.backgroundBase,
        border: Border(
          top: BorderSide(color: TetherColors.borderSubtle, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ─── Connection Status ───
          StatusIndicator(
            status: _mapStatus(connState),
            size: 6,
            showLabel: true,
          ),
          const SizedBox(width: 16),

          // ─── IP Address ───
          Text(
            ipLabel,
            style: TetherTheme.monoSmall.copyWith(fontSize: 11),
          ),

          const Spacer(),

          // ─── Latency ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: TetherColors.surfaceElevated,
            ),
            child: Text(
              '-- ms',
              style: TetherTheme.monoSmall.copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(width: 12),

          // ─── Peer Name / Sync Status ───
          Text(
            isConnected
                ? connDevice?.name ?? 'Connected'
                : 'Not synced',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: isConnected
                  ? TetherColors.accentSecondary
                  : TetherColors.textDisabled,
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
