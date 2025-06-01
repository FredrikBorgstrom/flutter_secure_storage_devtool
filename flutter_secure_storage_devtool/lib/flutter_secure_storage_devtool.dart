import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The event kind used to send Flutter Secure Storage data to the DevTools extension.
///
/// Users of this package should not need to reference this directly if using
/// the [postSecureStorageToDevTools] helper function.
const String secureStorageDevToolsEventKind = 'SecureStorage';

/// Posts Flutter Secure Storage data to the Flutter Secure Storage DevTools extension.
///
/// This function simplifies sending Flutter Secure Storage data from your application
/// to the DevTools extension by handling all the necessary conversion and event posting.
///
/// Args:
///   [storage]: The Flutter `FlutterSecureStorage` instance from your app.
///              The function will automatically extract all relevant information
///              and convert it to a format suitable for display in DevTools.
///
/// Example:
/// ```dart
/// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
/// import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';
///
/// void setupSecureStorageListener() {
///   final storage = FlutterSecureStorage();
///   if (kDebugMode) {
///     postSecureStorageToDevTools(storage);
///   }
/// }
/// ```
Future<void> postSecureStorageToDevTools(FlutterSecureStorage storage) async {
  if (!kDebugMode) return;
  try {
    // Get device information using device_info_plus
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceId = 'unknown-device';
    String deviceName = 'Unknown Device';

    if (kIsWeb) {
      // Web platform
      final webInfo = await deviceInfoPlugin.webBrowserInfo;
      deviceId = 'web-${webInfo.browserName.toString().toLowerCase()}';
      deviceName = '${webInfo.browserName} on ${webInfo.platform}';
    } else if (Platform.isAndroid) {
      // Android platform
      final androidInfo = await deviceInfoPlugin.androidInfo;
      deviceId = androidInfo.id;
      deviceName = androidInfo.model;
    } else if (Platform.isIOS) {
      // iOS platform
      final iosInfo = await deviceInfoPlugin.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown-ios';
      deviceName = iosInfo.utsname.machine;
    } else if (Platform.isMacOS) {
      // macOS platform
      final macOsInfo = await deviceInfoPlugin.macOsInfo;
      deviceId = macOsInfo.systemGUID ?? 'unknown-macos';
      deviceName = '${macOsInfo.computerName} (macOS ${macOsInfo.osRelease})';
    } else if (Platform.isWindows) {
      // Windows platform
      final windowsInfo = await deviceInfoPlugin.windowsInfo;
      deviceId = windowsInfo.deviceId;
      deviceName = '${windowsInfo.computerName} (Windows)';
    } else if (Platform.isLinux) {
      // Linux platform
      final linuxInfo = await deviceInfoPlugin.linuxInfo;
      deviceId = linuxInfo.machineId ?? 'unknown-linux';
      deviceName = linuxInfo.prettyName;
    } else {
      // Fallback for other platforms
      deviceId = 'device-${DateTime.now().millisecondsSinceEpoch}';
      deviceName = 'Unknown Platform';
    }

    // Read all values from secure storage
    final Map<String, String> allValues = await storage.readAll();

    // Create a map of key-value pairs
    final Map<String, dynamic> storageData = {};
    allValues.forEach((key, value) {
      storageData[key] = value;
    });

    final messageData = {
      'storageData': storageData,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Try both approaches to ensure the extension receives the data
    // Method 1: Use developer.postEvent (original approach)
    developer.postEvent(secureStorageDevToolsEventKind, messageData);

    // Method 2: Use developer.log with structured data that can be parsed
    developer.log(
      'SECURE_STORAGE_DATA: ${messageData.toString()}',
      name: secureStorageDevToolsEventKind,
      time: DateTime.now(),
    );

    developer.log(
      'Flutter Secure Storage DevTool: Data posted to DevTools with event kind: $secureStorageDevToolsEventKind',
      name: 'SecureStorageDevTool',
    );
    developer.log(
      'Device info: $deviceName ($deviceId)',
      name: 'SecureStorageDevTool',
    );
  } catch (e) {
    developer.log(
      'Error posting secure storage data to DevTools: $e',
      name: 'SecureStorageDevTool',
      error: e,
    );
  }
}

/// Registers listeners for changes to Flutter Secure Storage and posts updates to DevTools.
///
/// This function sets up real-time listeners for all existing keys and automatically
/// detects when new keys are added. Uses the native FlutterSecureStorage listener
/// mechanism for immediate change detection.
///
/// Args:
///   [storage]: The Flutter `FlutterSecureStorage` instance from your app.
///   [recheckInterval]: How often to check for new keys (defaults to 5 seconds).
///
/// Returns a [StreamSubscription] that can be cancelled to stop monitoring.
///
/// Example:
/// ```dart
/// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
/// import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';
///
/// void setupSecureStorageListener() {
///   final storage = FlutterSecureStorage();
///   if (kDebugMode) {
///     final timer = registerSecureStorageListener(storage);
///     // You can cancel monitoring later with: timer.cancel();
///   }
/// }
/// ```
Timer registerSecureStorageListener(
  FlutterSecureStorage storage, {
  Duration recheckInterval = const Duration(seconds: 5),
}) {
  if (!kDebugMode) {
    // Return a dummy timer that does nothing
    return Timer(Duration.zero, () {});
  }

  final Set<String> _monitoredKeys = <String>{};

  // Helper function to post updates when any value changes
  void _onStorageChange(String key, String? value) {
    developer.log(
      'Flutter Secure Storage DevTool: Key "$key" changed, posting update',
      name: 'SecureStorageDevTool',
    );
    postSecureStorageToDevTools(storage);
  }

  // Helper function to register listeners for new keys
  Future<void> _registerListenersForNewKeys() async {
    try {
      final allKeys = (await storage.readAll()).keys.toSet();
      final newKeys = allKeys.difference(_monitoredKeys);

      if (newKeys.isNotEmpty) {
        developer.log(
          'Flutter Secure Storage DevTool: Found ${newKeys.length} new keys: ${newKeys.join(", ")}',
          name: 'SecureStorageDevTool',
        );

        for (final key in newKeys) {
          storage.registerListener(
            key: key,
            listener: (value) => _onStorageChange(key, value),
          );
          _monitoredKeys.add(key);
        }

        // Post update when new keys are found
        postSecureStorageToDevTools(storage);
      }
    } catch (e) {
      developer.log(
        'Error checking for new secure storage keys: $e',
        name: 'SecureStorageDevTool',
        error: e,
      );
    }
  }

  // Register listeners for all existing keys and post initial data
  _registerListenersForNewKeys();

  // Set up periodic check for new keys (much less frequent than polling all data)
  final timer = Timer.periodic(recheckInterval, (timer) async {
    await _registerListenersForNewKeys();
  });

  developer.log(
    'Flutter Secure Storage DevTool: Real-time listeners registered (checking for new keys every ${recheckInterval.inSeconds}s)',
    name: 'SecureStorageDevTool',
  );

  return timer;
}

/// Helper function to compare two maps for equality
bool _mapsEqual(Map<String, String> map1, Map<String, String> map2) {
  if (map1.length != map2.length) return false;

  for (final key in map1.keys) {
    if (!map2.containsKey(key) || map1[key] != map2[key]) {
      return false;
    }
  }

  return true;
}

/// Stops all listeners for secure storage monitoring.
///
/// This is a convenience function to clean up all listeners when you're done
/// monitoring secure storage.
///
/// Args:
///   [storage]: The Flutter `FlutterSecureStorage` instance to clean up.
///
/// Example:
/// ```dart
/// // When you're done monitoring
/// stopSecureStorageListener(storage);
/// ```
void stopSecureStorageListener(FlutterSecureStorage storage) {
  if (!kDebugMode) return;

  storage.unregisterAllListeners();
  developer.log(
    'Flutter Secure Storage DevTool: All listeners stopped',
    name: 'SecureStorageDevTool',
  );
}
