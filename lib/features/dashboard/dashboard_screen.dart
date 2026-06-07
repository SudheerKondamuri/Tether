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

}}
