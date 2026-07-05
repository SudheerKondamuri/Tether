// ignore_for_file: constant_identifier_names

import 'dart:io' as io show InternetAddress, InternetAddressType;
import 'dart:typed_data';

class InternetAddressType {
  final io.InternetAddressType _delegate;
  const InternetAddressType._(this._delegate);

  static const IPv4 = InternetAddressType._(io.InternetAddressType.IPv4);
  static const IPv6 = InternetAddressType._(io.InternetAddressType.IPv6);
  static const unix = InternetAddressType._(io.InternetAddressType.unix);
  static const any = InternetAddressType._(io.InternetAddressType.any);
  static const pipe = InternetAddressType._(io.InternetAddressType.unix);
}

class InternetAddress implements io.InternetAddress {
  final io.InternetAddress _delegate;

  InternetAddress(String address, {InternetAddressType? type})
      : _delegate = io.InternetAddress(
          address,
          type: type?._delegate,
        );

  @override
  String get address => _delegate.address;

  @override
  String get host => _delegate.host;

  @override
  bool get isLoopback => _delegate.isLoopback;

  @override
  bool get isLinkLocal => _delegate.isLinkLocal;

  @override
  bool get isMulticast => _delegate.isMulticast;

  @override
  Uint8List get rawAddress => _delegate.rawAddress;

  @override
  io.InternetAddressType get type => _delegate.type;

  @override
  Future<io.InternetAddress> reverse() => _delegate.reverse();
}
