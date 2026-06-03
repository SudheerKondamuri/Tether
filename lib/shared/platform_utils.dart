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
    if (Platform.isLinux && linux != null) return linux;
    if (Platform.isAndroid && android != null) return android;
    if (Platform.isMacOS && macos != null) return macos;
    if (Platform.isWindows && windows != null) return windows;
    if (Platform.isIOS && ios != null) return ios;
    return fallback;
  }

  /// Returns a widget based on the current platform.
  static Widget platformWidget({
    Widget Function()? linux,
    Widget Function()? android,
    Widget Function()? macos,
    Widget Function()? windows,
    Widget Function()? fallback,
  }) {
    if (Platform.isLinux && linux != null) return linux();
    if (Platform.isAndroid && android != null) return android();
    if (Platform.isMacOS && macos != null) return macos();
    if (Platform.isWindows && windows != null) return windows();
    if (fallback != null) return fallback();
    return const SizedBox.shrink();
  }

  /// Executes a callback only on the specified platform.
  static void onPlatform({
    VoidCallback? linux,
    VoidCallback? android,
    VoidCallback? macos,
    VoidCallback? windows,
  }) {
    if (Platform.isLinux) linux?.call();
    if (Platform.isAndroid) android?.call();
    if (Platform.isMacOS) macos?.call();
    if (Platform.isWindows) windows?.call();
  }
}
