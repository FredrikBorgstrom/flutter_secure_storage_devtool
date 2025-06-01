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

    developer.postEvent(secureStorageDevToolsEventKind, messageData);
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

/// Registers a listener for changes to Flutter Secure Storage and posts updates to DevTools.
///
/// This function sets up a listener that will detect changes to the secure storage
/// and automatically post the updated data to the DevTools extension.
///
/// Args:
///   [storage]: The Flutter `FlutterSecureStorage` instance from your app.
///
/// Example:
/// ```dart
/// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
/// import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';
///
/// void setupSecureStorageListener() {
///   final storage = FlutterSecureStorage();
///   if (kDebugMode) {
///     registerSecureStorageListener(storage);
///   }
/// }
/// ```
void registerSecureStorageListener(FlutterSecureStorage storage) {
  if (!kDebugMode) return;

  // Initial post of all values
  postSecureStorageToDevTools(storage);

  // Set up a periodic check for changes (every 2 seconds)
  // Note: Flutter Secure Storage doesn't have a built-in listener mechanism
  // so we need to poll for changes
  final timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
    await postSecureStorageToDevTools(storage);
  });

  // Store the timer in a way that it can be cancelled when needed
  // This is a simple implementation - in a real app, you might want to
  // provide a way to stop the listener
  developer.log(
    'Flutter Secure Storage DevTool: Listener registered',
    name: 'SecureStorageDevTool',
  );
}
