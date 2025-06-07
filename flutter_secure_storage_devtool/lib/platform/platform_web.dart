/// Platform implementation for web environments that don't support dart:io
/// All platform checks return false on web since they're not applicable
library;

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
}
