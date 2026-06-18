import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/widgets/tether_card.dart';
import 'package:tether/shared/widgets/tether_button.dart';
import 'package:tether/shared/widgets/tether_text_field.dart';
import 'package:tether/shared/widgets/v2_locked_button.dart';
import 'package:tether/core/providers.dart';
import 'package:tether/shared/platform_utils.dart';

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
  bool _ignoringBatteryOptimizations = true;
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '${TetherConstants.tcpPort}');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _checkBatteryOptimization();
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
      _checkBatteryOptimization();
    }
  }

  Future<void> _checkBatteryOptimization() async {
    if (!PlatformUtils.isAndroid) return;
    try {
      const channel = MethodChannel(TetherConstants.foregroundServiceChannel);
      final bool ignoring = await channel.invokeMethod('isIgnoringBatteryOptimizations');
      if (mounted) {
        setState(() {
          _ignoringBatteryOptimizations = ignoring;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkPermission() async {
    final granted = await ref.read(notificationBridgeProvider).isPermissionGranted();
    if (granted) {
      await ref.read(notificationBridgeProvider).startListening();
    }
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

          if (PlatformUtils.isAndroid) ...[
            _SectionHeader(title: 'BACKGROUND PROTECTION'),
            const SizedBox(height: 8),
            TetherCard(
              child: Column(
                children: [
                  _ClickableRow(
                    label: 'Autostart / Startup Settings',
                    description: 'Allow Tether to run in background when swiped away',
                    onTap: () async {
                      const channel = MethodChannel(TetherConstants.foregroundServiceChannel);
                      final bool opened = await channel.invokeMethod('openAutostartSettings');
                      if (!context.mounted) return;
                      if (!opened) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open startup settings. Please configure manually.'),
                            backgroundColor: TetherColors.accentDanger,
                          ),
                        );
                      }
                    },
                    trailing: const Icon(
                      Icons.launch_rounded,
                      color: TetherColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const Divider(color: TetherColors.borderSubtle, height: 1),
                  _ClickableRow(
                    label: 'Battery Optimization Whitelist',
                    description: _ignoringBatteryOptimizations
                        ? 'Optimizations disabled (recommended)'
                        : 'Tap to exempt from battery savings',
                    onTap: () async {
                      if (!_ignoringBatteryOptimizations) {
                        const channel = MethodChannel(TetherConstants.foregroundServiceChannel);
                        await channel.invokeMethod('requestIgnoreBatteryOptimizations');
                      }
                    },
                    trailing: Icon(
                      _ignoringBatteryOptimizations
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: _ignoringBatteryOptimizations
                          ? TetherColors.accentSecondary
                          : TetherColors.accentWarning,
                    ),
                  ),
                  const Divider(color: TetherColors.borderSubtle, height: 1),
                  _ClickableRow(
                    label: 'Background Alive Guide',
                    description: 'Instructions to prevent service drops on Vivo/Xiaomi/etc.',
                    onTap: _showBackgroundAliveGuide,
                    trailing: const Icon(
                      Icons.help_outline_rounded,
                      color: TetherColors.accentPrimary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

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
          const SizedBox(height: 8),
          TetherCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Certificate Fingerprint',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TetherColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: TetherColors.surfaceHigher,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    'Loading...',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: TetherColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TetherButton(
                  label: 'Regenerate Certificate',
                  variant: TetherButtonVariant.danger,
                  isSmall: true,
                  icon: Icons.refresh,
                  onPressed: () {
                    // TODO: Regenerate TLS cert
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── v2 Features ───
          _SectionHeader(title: 'UPCOMING'),
          const SizedBox(height: 8),
          TetherCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'These features are planned for v2:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: TetherColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    V2LockedButton(label: 'SMS Gateway', icon: Icons.sms),
                    V2LockedButton(
                        label: 'Remote Shell', icon: Icons.terminal),
                    V2LockedButton(
                        label: 'Audio Routing', icon: Icons.headphones),
                    V2LockedButton(
                        label: 'Hotspot Toggle', icon: Icons.wifi_tethering),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── About ───
          _SectionHeader(title: 'ABOUT'),
          const SizedBox(height: 8),
          TetherCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'App', value: TetherConstants.appName),
                _InfoRow(
                    label: 'Version', value: 'v${TetherConstants.appVersion}'),
                _InfoRow(label: 'TCP Port', value: '${TetherConstants.tcpPort}'),
                _InfoRow(label: 'Max Clipboard', value: '${TetherConstants.clipboardMaxHistory}'),
                _InfoRow(label: 'Encryption', value: 'TLS 1.3 (self-signed)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBackgroundAliveGuide() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: TetherColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TetherRadius.modal),
            side: const BorderSide(color: TetherColors.borderSubtle),
          ),
          title: Row(
            children: const [
              Icon(Icons.shield_outlined, color: TetherColors.accentPrimary),
              SizedBox(width: 8),
              Text(
                'Background Alive Guide',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: TetherColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'To prevent Android from killing Tether when swiped from recent tasks, configure these settings:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: TetherColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _buildGuideStep(
                  step: '1',
                  title: 'Enable Autostart / Background Startup',
                  description: 'Allow Tether to run background tasks autonomously by toggling its switch in the Autostart manager.',
                ),
                const SizedBox(height: 12),
                _buildGuideStep(
                  step: '2',
                  title: 'Allow High Background Power',
                  description: 'Go to Settings > Battery > Background power consumption (on Vivo/iQOO) and choose "Allow high background power consumption" (or set Battery usage to "Unrestricted" in App Info).',
                ),
                const SizedBox(height: 12),
                _buildGuideStep(
                  step: '3',
                  title: 'Lock Tether in Recent Tasks',
                  description: 'Open recent tasks view, swipe down on the Tether card (or long-press it), and select the lock icon. This prevents the OS from clearing it when swiped away.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Got it',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: TetherColors.accentPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideStep({
    required String step,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: TetherColors.surfaceHigher,
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: TetherColors.accentPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: TetherColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: TetherColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: TetherColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: TetherColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: TetherColors.accentPrimary,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
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
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
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

class _ClickableRow extends StatelessWidget {
  final String label;
  final String description;
  final VoidCallback onTap;
  final Widget trailing;

  const _ClickableRow({
    required this.label,
    required this.description,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: TetherColors.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: TetherColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
