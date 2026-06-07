import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/widgets/tether_card.dart';
import 'package:tether/shared/widgets/tether_badge.dart';
import 'package:tether/shared/widgets/status_indicator.dart';
import 'package:tether/core/networking/connection_manager.dart';

/// Linux Dashboard screen — system overview, device info, uptime, stats.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Timer _uptimeTimer;
  Duration _uptime = Duration.zero;
  final DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _uptime = DateTime.now().difference(_startedAt);
      });
    });
  }

  @override
  void dispose() {
    _uptimeTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(connectionStateProvider);
    final deviceAsync = ref.watch(connectedDeviceProvider);

    final connectionState = connectionAsync.valueOrNull ?? TetherConnectionState.disconnected;
    final connDevice = deviceAsync.valueOrNull;

    return Container(
      color: TetherColors.backgroundBase,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ─── Title ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: TetherColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'v${TetherConstants.appVersion}',
                style: TetherTheme.monoSmall,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Connection Status Card ───
          TetherCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusIndicator(
                      status: _mapConnectionStatus(connectionState),
                      size: 10,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _connectionLabel(connectionState),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: TetherColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TetherBadge(
                      label: _connectionLabel(connectionState).toUpperCase(),
                      color: _connectionColor(connectionState),
                      isSmall: true,
                    ),
                  ],
                ),
                if (connDevice != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Device',
                    value: connDevice.name,
                  ),
                  _InfoRow(
                    label: 'Platform',
                    value: connDevice.platform,
                  ),
                  _InfoRow(
                    label: 'IP',
                    value: '${connDevice.ip}:${connDevice.port}',
                    isMono: true,
                  ),
                  if (connDevice.battery != null)
                    _InfoRow(
                      label: 'Battery',
                      value: '${connDevice.battery}%',
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Stats Grid ───
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Uptime',
                  value: _formatDuration(_uptime),
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Clipboard',
                  value: '0 items',
                  icon: Icons.content_paste_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Files Sent',
                  value: '0',
                  icon: Icons.upload_file_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Notifications',
                  value: '0',
                  icon: Icons.notifications_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── System Info ───
          Text(
            'SYSTEM',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TetherCard(
            child: Column(
              children: [
                _InfoRow(label: 'TCP Port', value: '${TetherConstants.tcpPort}', isMono: true),
                _InfoRow(label: 'Database', value: TetherConstants.databaseName, isMono: true),
                _InfoRow(label: 'Encryption', value: 'TLS 1.3'),
                _InfoRow(label: 'Discovery', value: TetherConstants.mdnsServiceType, isMono: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _connectionLabel(TetherConnectionState state) {
    switch (state) {
      case TetherConnectionState.connected:
        return 'Connected';
      case TetherConnectionState.connecting:
        return 'Connecting...';
      case TetherConnectionState.searching:
        return 'Searching...';
      case TetherConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  Color _connectionColor(TetherConnectionState state) {
    switch (state) {
      case TetherConnectionState.connected:
        return TetherColors.accentSecondary;
      case TetherConnectionState.connecting:
      case TetherConnectionState.searching:
        return TetherColors.accentPrimary;
      case TetherConnectionState.disconnected:
        return TetherColors.textDisabled;
    }
  }

  ConnectionStatus _mapConnectionStatus(TetherConnectionState state) {
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

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TetherCard(
      child: Row(
        children: [
          Icon(icon, size: 20, color: TetherColors.accentPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: TetherColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: TetherColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMono;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: TetherColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: isMono ? 'JetBrainsMono' : 'Inter',
                fontSize: 13,
                color: TetherColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
