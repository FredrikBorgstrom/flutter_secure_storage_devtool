/// Platform stub implementation for environments that don't support dart:io
/// This file should never be used in practice due to conditional imports
library;

class Platform {
  static bool get isAndroid => throw UnsupportedError('Platform not supported');
  static bool get isIOS => throw UnsupportedError('Platform not supported');
  static bool get isMacOS => throw UnsupportedError('Platform not supported');
  static bool get isWindows => throw UnsupportedError('Platform not supported');
  static bool get isLinux => throw UnsupportedError('Platform not supported');
}
