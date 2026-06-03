import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart' as pc;
import 'package:asn1lib/asn1lib.dart';

/// Manages TLS certificates — generation, storage, fingerprinting.
class TlsManager {
  static const _certFilename = 'tether_cert.pem';
  static const _keyFilename = 'tether_key.pem';

  /// Get the directory where certs are stored.
  static Future<String> _certDir() async {
    final dir = await getApplicationSupportDirectory();
    final certDir = Directory(p.join(dir.path, 'certs'));
    if (!await certDir.exists()) {
      await certDir.create(recursive: true);
    }
    return certDir.path;
  }

  /// Generate a self-signed certificate if one doesn't already exist.
  /// Returns (certPath, keyPath).
  static Future<(String, String)> ensureCertificate() async {
    final dir = await _certDir();
    final certPath = p.join(dir, _certFilename);
    final keyPath = p.join(dir, _keyFilename);

    if (await File(certPath).exists() && await File(keyPath).exists()) {
      return (certPath, keyPath);
    }

    // Try openssl first (faster, available on Linux)
    final opensslResult = await _tryOpenssl(certPath, keyPath);
    if (opensslResult) {
      return (certPath, keyPath);
    }

    // Fall back to pure Dart cert generation
    await _generatePureDart(certPath, keyPath);
    return (certPath, keyPath);
  }

  /// Try generating cert with openssl CLI.
  static Future<bool> _tryOpenssl(String certPath, String keyPath) async {
    try {
      final result = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey', 'rsa:2048',
        '-keyout', keyPath,
        '-out', certPath,
        '-days', '365',
        '-nodes',
        '-subj', '/CN=tether-device',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Pure-Dart RSA key + self-signed X.509 cert generation.
  static Future<void> _generatePureDart(
      String certPath, String keyPath) async {
    final secureRandom = pc.FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));

    // Generate RSA key pair
    final keyGen = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as pc.RSAPublicKey;
    final privateKey = pair.privateKey as pc.RSAPrivateKey;

    // Encode private key to PEM
    final privKeyPem = _encodeRSAPrivateKeyToPem(privateKey);
    await File(keyPath).writeAsString(privKeyPem);

    // Generate self-signed X.509 certificate
    final certPem = _generateSelfSignedCert(publicKey, privateKey, secureRandom);
    await File(certPath).writeAsString(certPem);
  }

  static String _encodeRSAPrivateKeyToPem(pc.RSAPrivateKey key) {
    final seq = ASN1Sequence();
    seq.add(ASN1Integer(BigInt.zero)); // version
    seq.add(ASN1Integer(key.modulus!));
    seq.add(ASN1Integer(key.publicExponent!));
    seq.add(ASN1Integer(key.privateExponent!));
    seq.add(ASN1Integer(key.p!));
    seq.add(ASN1Integer(key.q!));
    seq.add(ASN1Integer(key.privateExponent! % (key.p! - BigInt.one))); // d mod (p-1)
    seq.add(ASN1Integer(key.privateExponent! % (key.q! - BigInt.one))); // d mod (q-1)
    seq.add(ASN1Integer(key.q!.modInverse(key.p!))); // q^-1 mod p

    final encoded = base64Encode(seq.encodedBytes);
    final lines = <String>[];
    lines.add('-----BEGIN RSA PRIVATE KEY-----');
    for (var i = 0; i < encoded.length; i += 64) {
      lines.add(encoded.substring(i, i + 64 > encoded.length ? encoded.length : i + 64));
    }
    lines.add('-----END RSA PRIVATE KEY-----');

}}
