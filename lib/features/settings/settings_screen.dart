import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/widgets/tether_card.dart';
import 'package:tether/shared/widgets/tether_button.dart';
import 'package:tether/shared/widgets/tether_text_field.dart';
import 'package:tether/shared/widgets/v2_locked_button.dart';
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/core/services/notification_bridge_service.dart';

/// Settings screen with connection, pairing, modules, and app config.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  bool _clipboardSync = true;
  bool _notificationMirror = true;
  bool _notificationPermissionGranted = false;
  bool _autoConnect = true;
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '${TetherConstants.tcpPort}');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final granted = await ref.read(notificationBridgeProvider).isPermissionGranted();
    if (mounted) {
      setState(() {
        _notificationPermissionGranted = granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TetherColors.backgroundBase,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ─── Header ───
          const Text(
            'Settings',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: TetherColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // ─── Connection ───
          _SectionHeader(title: 'CONNECTION'),
          const SizedBox(height: 8),
          TetherCard(
            child: Column(
              children: [
                _SwitchRow(
                  label: 'Auto-connect',
                  description: 'Reconnect to last known device on launch',
                  value: _autoConnect,
                  onChanged: (v) => setState(() => _autoConnect = v),
                ),
                const Divider(
                    color: TetherColors.borderSubtle, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manual Connection',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: TetherColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TetherTextField(
                              controller: _ipController,
                              hint: '192.168.x.x',
                              isMonospace: true,
                              prefixIcon: Icons.wifi,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TetherTextField(
                              controller: _portController,
                              hint: '5280',
                              isMonospace: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TetherButton(
                            label: 'Connect',
                            isSmall: true,
                            onPressed: () async {
                              final ip = _ipController.text.trim();
                              final port = int.tryParse(_portController.text.trim()) ?? TetherConstants.tcpPort;
                              if (ip.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a valid IP address.'),
                                    backgroundColor: TetherColors.accentDanger,
                                  ),
                                );
                                return;
                              }
                              
                              final success = await ref.read(connectionManagerProvider).connectTo(host: ip, port: port);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Connected successfully!' : 'Connection failed.'),
                                  backgroundColor: success ? TetherColors.accentSecondary : TetherColors.accentDanger,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Modules ───
          _SectionHeader(title: 'MODULES'),
          const SizedBox(height: 8),
          TetherCard(
            child: Column(
              children: [
                _SwitchRow(
                  label: 'Clipboard Sync',
                  description: 'Share clipboard between devices',
                  value: _clipboardSync,
                  onChanged: (v) => setState(() => _clipboardSync = v),
                ),
                const Divider(
                    color: TetherColors.borderSubtle, height: 1),
                _SwitchRow(
                  label: 'Notification Mirror',
                  description: _notificationPermissionGranted
                      ? 'Show Android notifications on Linux'
                      : 'Notification Access permission required. Tap to grant.',
                  value: _notificationMirror && _notificationPermissionGranted,
                  onChanged: (v) async {
                    if (v) {
                      final granted = await ref.read(notificationBridgeProvider).isPermissionGranted();
                      if (!granted) {
                        await ref.read(notificationBridgeProvider).requestPermission();
                      } else {
                        await ref.read(notificationBridgeProvider).startListening();
                        setState(() {
                          _notificationMirror = true;
                          _notificationPermissionGranted = true;
                        });
                      }
                    } else {
                      await ref.read(notificationBridgeProvider).stopListening();
                      setState(() => _notificationMirror = false);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Security ───
          _SectionHeader(title: 'SECURITY'),

}}
