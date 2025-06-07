/// Platform implementation for environments that support dart:io (native platforms)
library;

import 'dart:io' as io;

class Platform {
  static bool get isAndroid => io.Platform.isAndroid;
  static bool get isIOS => io.Platform.isIOS;
  static bool get isMacOS => io.Platform.isMacOS;
  static bool get isWindows => io.Platform.isWindows;
  static bool get isLinux => io.Platform.isLinux;
}
