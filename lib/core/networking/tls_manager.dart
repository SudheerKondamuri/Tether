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
    return lines.join('\n');
  }

  static String _generateSelfSignedCert(
      pc.RSAPublicKey pubKey, pc.RSAPrivateKey privKey, pc.SecureRandom rng) {
    // Build a minimal X.509 v3 certificate using ASN1
    final tbsCert = ASN1Sequence();

    // Version (v3)
    final versionContext = ASN1Object.fromBytes(
        Uint8List.fromList([0xA0, 0x03, 0x02, 0x01, 0x02]));
    tbsCert.add(versionContext);

    // Serial number
    tbsCert.add(ASN1Integer(BigInt.from(DateTime.now().millisecondsSinceEpoch)));

    // Signature algorithm: SHA256withRSA
    final sigAlg = ASN1Sequence();
    sigAlg.add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.11'));
    sigAlg.add(ASN1Null());
    tbsCert.add(sigAlg);

    // Issuer
    final issuer = ASN1Sequence();
    final cnSet = ASN1Set();
    final cnSeq = ASN1Sequence();
    cnSeq.add(ASN1ObjectIdentifier.fromComponentString('2.5.4.3')); // CN
    cnSeq.add(ASN1UTF8String('tether-device'));
    cnSet.add(cnSeq);
    issuer.add(cnSet);
    tbsCert.add(issuer);

    // Validity
    final validity = ASN1Sequence();
    final now = DateTime.now().toUtc();
    validity.add(ASN1UtcTime(now));
    validity.add(ASN1UtcTime(now.add(const Duration(days: 365))));
    tbsCert.add(validity);

    // Subject (same as issuer for self-signed)
    tbsCert.add(issuer);

    // Subject public key info
    final pubKeyInfo = ASN1Sequence();
    final pubKeyAlg = ASN1Sequence();
    pubKeyAlg.add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'));
    pubKeyAlg.add(ASN1Null());
    pubKeyInfo.add(pubKeyAlg);

    final pubKeySeq = ASN1Sequence();
    pubKeySeq.add(ASN1Integer(pubKey.modulus!));
    pubKeySeq.add(ASN1Integer(pubKey.exponent!));
    pubKeyInfo.add(ASN1BitString(
        Uint8List.fromList([0x00, ...pubKeySeq.encodedBytes])));
    tbsCert.add(pubKeyInfo);

    // Sign TBS certificate
    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201');
    signer.init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privKey));
    final signature = signer.generateSignature(Uint8List.fromList(tbsCert.encodedBytes));

    // Build full certificate
    final cert = ASN1Sequence();
    cert.add(tbsCert);
    cert.add(sigAlg);
    cert.add(ASN1BitString(
        Uint8List.fromList([0x00, ...signature.bytes])));

    final encoded = base64Encode(cert.encodedBytes);
    final lines = <String>[];
    lines.add('-----BEGIN CERTIFICATE-----');
    for (var i = 0; i < encoded.length; i += 64) {
      lines.add(encoded.substring(i, i + 64 > encoded.length ? encoded.length : i + 64));
    }
    lines.add('-----END CERTIFICATE-----');
    return lines.join('\n');
  }

  /// Compute SHA-256 fingerprint of a PEM certificate file.
  static Future<String> fingerprint(String certPath) async {
    final pem = await File(certPath).readAsString();
    final b64 = pem
        .replaceAll('-----BEGIN CERTIFICATE-----', '')
        .replaceAll('-----END CERTIFICATE-----', '')
        .replaceAll(RegExp(r'\s'), '');
    final bytes = base64Decode(b64);
    final digest = sha256.convert(bytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':');
  }

  /// Create a SecurityContext from cert and key files.
  static Future<SecurityContext> createServerContext() async {
    final (certPath, keyPath) = await ensureCertificate();
    final ctx = SecurityContext()
      ..useCertificateChain(certPath)
      ..usePrivateKey(keyPath);
    return ctx;
  }

  /// Create a SecurityContext for client that trusts a specific cert.
  static SecurityContext createClientContext(String trustedCertPem) {
    final ctx = SecurityContext()
      ..setTrustedCertificatesBytes(utf8.encode(trustedCertPem));
    return ctx;
  }

  /// Generate a random 6-digit PIN.
  static String generatePin() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }
}
