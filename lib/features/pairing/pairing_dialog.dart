import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/widgets/tether_button.dart';
import 'package:tether/shared/widgets/tether_text_field.dart';
import 'package:tether/core/networking/tls_manager.dart';
import 'package:tether/core/providers.dart';

/// QR-based pairing flow — shows on the server side (Linux typically).
class PairingDialog extends StatefulWidget {
  final String? ip;
  final int port;

  const PairingDialog({
    super.key,
    this.ip,
    required this.port,
  });

  @override
  State<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<PairingDialog> {
  String _pin = '';
  String _fingerprint = '';
  bool _loading = true;
  List<String> _localIps = [];
  String _selectedIp = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    _pin = TlsManager.generatePin();
    final (certPath, _) = await TlsManager.ensureCertificate();
    _fingerprint = await TlsManager.fingerprint(certPath);

    if (widget.ip != null && widget.ip != '0.0.0.0') {
      _selectedIp = widget.ip!;
      _localIps = [_selectedIp];
    } else {
      _localIps = await _getLocalIps();
      if (_localIps.isNotEmpty) {
        _selectedIp = _localIps.first;
      } else {
        _selectedIp = '127.0.0.1';
        _localIps = [_selectedIp];
      }
    }
    setState(() => _loading = false);
  }

  Future<List<String>> _getLocalIps() async {
    final List<(String, String)> interfaceIps = [];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        for (var addr in interface.addresses) {
          final ip = addr.address;
          if (!addr.isLoopback && !ip.startsWith('169.254.')) {
            interfaceIps.add((name, ip));
          }
        }
      }
    } catch (_) {}

    interfaceIps.sort((a, b) {
      int score(String name) {
        if (name.contains('wlan') || name.contains('wlp') || name.contains('wifi')) {
          return 3;
        }
        if (name.contains('eth') || name.contains('enp') || name.contains('eno') || name.contains('ethernet')) {
          return 2;
        }
        if (name.contains('docker') || name.contains('br-') || name.contains('veth') || name.contains('lo')) {
          return 0;
        }
        return 1;
      }
      return score(b.$1).compareTo(score(a.$1));
    });

    return interfaceIps.map((e) => e.$2).toList();
  }

  Map<String, dynamic> get _qrData => {
        TetherConstants.qrKeyIp: _selectedIp,
        TetherConstants.qrKeyPort: widget.port,
        TetherConstants.qrKeyPin: _pin,
        TetherConstants.qrKeyFingerprint: _fingerprint,
      };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TetherColors.surfaceHigher,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: TetherColors.accentPrimary,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pair Device',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: TetherColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scan this QR code from your Android device',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: TetherColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── QR Code ───
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(
                      data: jsonEncode(_qrData),
                      version: QrVersions.auto,
                      size: TetherConstants.qrCodeSize,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0D0D0F),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0D0D0F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── IP Selector ───
                  if (_localIps.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: TetherColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(TetherRadius.card),
                        border: Border.all(color: TetherColors.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedIp,
                          dropdownColor: TetherColors.surfaceElevated,
                          icon: const Icon(Icons.arrow_drop_down, color: TetherColors.textSecondary),
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            color: TetherColors.textPrimary,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedIp = newValue;
                              });
                            }
                          },
                          items: _localIps.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'IP Address: $_selectedIp',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        color: TetherColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ─── PIN ───
                  const Text(
                    'OR ENTER PIN',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: TetherColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pin,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: TetherColors.accentPrimary,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Fingerprint ───
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TetherColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CERT FINGERPRINT',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: TetherColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _fingerprint,
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 10,
                            color: TetherColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TetherButton(
                        label: 'Cancel',
                        variant: TetherButtonVariant.ghost,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// QR scanner pairing dialog for the client side (Android typically).
class PairingScanDialog extends ConsumerStatefulWidget {
  const PairingScanDialog({super.key});

  @override
  ConsumerState<PairingScanDialog> createState() => _PairingScanDialogState();
}

class _PairingScanDialogState extends ConsumerState<PairingScanDialog> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '${TetherConstants.tcpPort}');
  final _pinController = TextEditingController();
  bool _isConnecting = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _pinController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
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

    setState(() => _isConnecting = true);

    try {
      final manager = ref.read(connectionManagerProvider);
      final success = await manager.connectTo(host: ip, port: port);
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully paired and connected!'),
            backgroundColor: TetherColors.accentSecondary,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection failed. Please check IP and network.'),
            backgroundColor: TetherColors.accentDanger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: TetherColors.accentDanger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final discoveredDevices = ref.watch(discoveredDevicesProvider).valueOrNull ?? [];

    return Dialog(
      backgroundColor: TetherColors.surfaceHigher,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pair Device',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: TetherColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Scan QR code, enter IP manually, or select a discovered device.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: TetherColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // ─── Camera Preview (MobileScanner) ───
              Container(
                width: 280,
                height: 200,
                decoration: BoxDecoration(
                  color: TetherColors.backgroundBase,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TetherColors.borderSubtle),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            final String? code = barcode.rawValue;
                            if (code != null) {
                              try {
                                final Map<String, dynamic> data = jsonDecode(code);
                                final String? ip = data[TetherConstants.qrKeyIp];
                                final int? port = data[TetherConstants.qrKeyPort];
                                final String? pin = data[TetherConstants.qrKeyPin];
                                if (ip != null) {
                                  setState(() {
                                    _ipController.text = ip;
                                    if (port != null) {
                                      _portController.text = port.toString();
                                    }
                                    if (pin != null) {
                                      _pinController.text = pin;
                                    }
                                  });
                                  _connect();
                                  break;
                                }
                              } catch (_) {
                                // ignore bad QR codes
                              }
                            }
                          }
                        },
                      ),
                      // Overlay aiming reticle
                      Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: TetherColors.accentPrimary.withAlpha(150),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Discovered Devices Section ───
              if (discoveredDevices.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'DISCOVERED DEVICES',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: TetherColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  decoration: BoxDecoration(
                    color: TetherColors.backgroundBase,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: TetherColors.borderSubtle),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final dev = discoveredDevices[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: const Icon(Icons.devices, size: 16, color: TetherColors.accentSecondary),
                        title: Text(
                          dev.name,
                          style: const TextStyle(fontSize: 13, color: TetherColors.textPrimary),
                        ),
                        subtitle: Text(
                          '${dev.ip}:${dev.port}',
                          style: TetherTheme.monoSmall.copyWith(fontSize: 11),
                        ),
                        onTap: () {
                          setState(() {
                            _ipController.text = dev.ip;
                            _portController.text = dev.port.toString();
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ─── Manual Input ───
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'OR ENTER MANUALLY',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: TetherColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TetherTextField(
                      controller: _ipController,
                      hint: 'IP address',
                      isMonospace: true,
                      prefixIcon: Icons.wifi,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TetherTextField(
                      controller: _portController,
                      hint: 'Port',
                      isMonospace: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TetherTextField(
                controller: _pinController,
                hint: '6-digit PIN (optional)',
                isMonospace: true,
                prefixIcon: Icons.pin,
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TetherButton(
                    label: 'Cancel',
                    variant: TetherButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  if (_isConnecting)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TetherColors.accentPrimary,
                        ),
                      ),
                    )
                  else
                    TetherButton(
                      label: 'Connect',
                      onPressed: _connect,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
