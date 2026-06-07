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
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/core/networking/mdns_discovery.dart';

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

}
