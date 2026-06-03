import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';

/// Platform abstraction layer — all platform checks go through here.
/// Never use Platform.isAndroid directly in UI or feature code.
class PlatformUtils {
  PlatformUtils._();

  static bool get isLinux => Platform.isLinux;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isIOS => Platform.isIOS;

  static bool get isDesktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static String get platformName {
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Returns a value based on the current platform.
  static T platformValue<T>({
    T? linux,
    T? android,
    T? macos,
    T? windows,
    T? ios,
    required T fallback,
  }) {

}}
