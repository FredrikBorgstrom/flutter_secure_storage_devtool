import 'dart:async';
import 'dart:developer' as developer;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Use conditional imports to support Web and WASM compatibility
import 'platform/platform.dart';

/// The event kind used to send Flutter Secure Storage data to the DevTools extension.
///
/// Users of this package should not need to reference this directly if using
/// the [postSecureStorageToDevTools] helper function.
const String secureStorageDevToolsEventKind = 'SecureStorage';

/// The event kind used to send specific Flutter Secure Storage updates to the DevTools extension.
///
/// This is used for individual key-value changes.
const String secureStorageUpdateEventKind = 'SecureStorageUpdate';

/// The event kind used to receive commands from the DevTools extension.
///
/// This is used for edit/delete operations initiated from the extension.
const String secureStorageCommandEventKind = 'SecureStorageCommand';

// Global storage instance for command handling
FlutterSecureStorage? _globalStorageInstance;

// Track which extensions have been registered to prevent double registration
bool _extensionsRegistered = false;

// Track monitored keys globally to ensure proper cleanup on restart
Set<String> _globalMonitoredKeys = <String>{};

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
    final deviceInfo = await _getDeviceInfo();

    // Read all values from secure storage
    final Map<String, String> allValues = await storage.readAll();

    // Create a map of key-value pairs
    final Map<String, dynamic> storageData = {};
    allValues.forEach((key, value) {
      storageData[key] = value;
    });

    final messageData = {
      'storageData': storageData,
      'deviceId': deviceInfo['deviceId'],
      'deviceName': deviceInfo['deviceName'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Try both approaches to ensure the extension receives the data
    // Method 1: Use developer.postEvent (original approach)
    developer.postEvent(secureStorageDevToolsEventKind, messageData);

    // Method 2: Use developer.log with structured data that can be parsed
    /* developer.log(
      'SECURE_STORAGE_DATA: ${messageData.toString()}',
      name: secureStorageDevToolsEventKind,
      time: DateTime.now(),
    );

    developer.log(
      'Flutter Secure Storage DevTool: Data posted to DevTools with event kind: $secureStorageDevToolsEventKind',
      name: 'SecureStorageDevTool',
    );
    developer.log(
      'Device info: ${deviceInfo['deviceName']} (${deviceInfo['deviceId']})',
      name: 'SecureStorageDevTool',
    ); */
  } catch (e) {
    // Error handling without logging
  }
}

/// Posts a specific Flutter Secure Storage key-value update to the DevTools extension.
///
/// This function is used to send individual key-value changes instead of all data.
///
/// Args:
///   [key]: The storage key that was changed.
///   [value]: The new value (can be null for deletions).
///   [operation]: The type of operation ('set', 'delete', 'clear').
///
/// Example:
/// ```dart
/// import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';
///
/// // When a key is updated
/// postSecureStorageUpdateToDevTools('user_token', 'new_token_value', 'set');
///
/// // When a key is deleted
/// postSecureStorageUpdateToDevTools('user_token', null, 'delete');
/// ```
Future<void> postSecureStorageUpdateToDevTools(
  String key,
  String? value,
  String operation,
) async {
  if (!kDebugMode) return;
  try {
    // Get device information using device_info_plus
    final deviceInfo = await _getDeviceInfo();

    final messageData = {
      'key': key,
      'value': value,
      'operation': operation, // 'set', 'delete', 'clear'
      'deviceId': deviceInfo['deviceId'],
      'deviceName': deviceInfo['deviceName'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Post the update event
    developer.postEvent(secureStorageUpdateEventKind, messageData);
  } catch (e) {
    // Error handling without logging
  }
}

/// Handles commands received from the DevTools extension.
///
/// This function processes edit and delete commands sent from the extension.
///
/// Args:
///   [command]: The command object containing operation details.
///   [storage]: The Flutter Secure Storage instance to operate on.
Future<void> _handleStorageCommand(
    Map<String, dynamic> command, FlutterSecureStorage storage) async {
  try {
    final operation = command['operation'] as String?;
    final key = command['key'] as String?;
    final value =
        command.containsKey('value') ? command['value'] as String? : null;

    // Validate required parameters based on operation
    if (operation == 'deleteAll') {
      // deleteAll doesn't need a key
    } else if (key == null) {
      return;
    }

    switch (operation) {
      case 'edit':
        if (value != null && key != null) {
          await storage.write(key: key, value: value);
          // Post individual update first for immediate feedback
          postSecureStorageUpdateToDevTools(key, value, 'set');
          // Also post all data to ensure the 'all data' view stays synchronized
          postSecureStorageToDevTools(storage);
        }
        break;
      case 'delete':
        if (key != null) {
          await storage.delete(key: key);
          // Post individual update first for immediate feedback
          postSecureStorageUpdateToDevTools(key, null, 'delete');
          // Also post all data to ensure the 'all data' view stays synchronized
          postSecureStorageToDevTools(storage);
        }
        break;
      case 'deleteAll':
        try {
          // Check what data exists before deletion
          final beforeData = await storage.readAll();

          // Perform the delete all operation
          await storage.deleteAll();

          // Verify deletion worked
          final afterData = await storage.readAll();

          if (afterData.isNotEmpty) {
            // Try individual deletion as fallback
            for (final key in afterData.keys) {
              try {
                await storage.delete(key: key);
              } catch (e) {
                // Continue with other keys if one fails
              }
            }
          }

          // Post update to DevTools (using special key to indicate all deleted)
          postSecureStorageUpdateToDevTools('*', null, 'deleteAll');
          // Also post fresh data to update the full view
          postSecureStorageToDevTools(storage);
        } catch (e, stackTrace) {
          // Still post updates to show the current state
          postSecureStorageToDevTools(storage);
        }
        break;
      default:
        // Unknown operation
        break;
    }
  } catch (e) {
    // Error handling without logging
  }
}

/// Helper function to get device information
Future<Map<String, String>> _getDeviceInfo() async {
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

  return {
    'deviceId': deviceId,
    'deviceName': deviceName,
  };
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

  // Store the storage instance globally for command handling
  _globalStorageInstance = storage;

  // Register service extension for receiving commands from DevTools
  _registerCommandExtension();

  // Clear any existing listeners to ensure clean state on restart
  // This is important to prevent duplicate listeners and ensure proper cleanup
  try {
    storage.unregisterAllListeners();
  } catch (e) {
    // Error handling without logging
  }

  // Reset the global monitored keys set to ensure no stale data from previous sessions
  _globalMonitoredKeys.clear();

  // Helper function to post updates when any value changes
  void onStorageChange(String key, String? value) {
    // Post individual update first for immediate feedback
    postSecureStorageUpdateToDevTools(key, value, 'set');
    // Also post all data to ensure the 'all data' view stays synchronized
    postSecureStorageToDevTools(storage);
  }

  // Helper function to register listeners for new keys
  Future<void> registerListenersForNewKeys() async {
    try {
      final allKeys = (await storage.readAll()).keys.toSet();
      final newKeys = allKeys.difference(_globalMonitoredKeys);

      if (newKeys.isNotEmpty) {
        for (final key in newKeys) {
          storage.registerListener(
            key: key,
            listener: (value) => onStorageChange(key, value),
          );
          _globalMonitoredKeys.add(key);
        }

        // Post full data update when new keys are found
        postSecureStorageToDevTools(storage);
      }
    } catch (e) {
      // Error handling without logging
    }
  }

  // Register listeners for all existing keys and post initial data
  registerListenersForNewKeys();

  // Post initial data immediately (without delay)
  Future<void> postInitialData() async {
    try {
      await postSecureStorageToDevTools(storage);
    } catch (e) {
      // Error handling without logging
    }
  }

  // Post initial data immediately
  postInitialData();

  // Also post after a short delay to ensure DevTools extension is ready (fallback)
  Timer(const Duration(milliseconds: 300), () async {
    await postInitialData();
  });

  // Post initial data after a longer delay as well (final fallback)
  Timer(const Duration(milliseconds: 1000), () async {
    await postInitialData();
  });

  // Set up periodic check for new keys (much less frequent than polling all data)
  final timer = Timer.periodic(recheckInterval, (timer) async {
    await registerListenersForNewKeys();
  });

  return timer;
}

/// Registers the service extension for handling commands from DevTools
void _registerCommandExtension() {
  // Prevent double registration
  if (_extensionsRegistered) {
    return;
  }

  try {
    // Register test communication handler first
    developer.registerExtension(
      'ext.secure_storage.testCommunication',
      (method, parameters) async {
        return developer.ServiceExtensionResponse.result(
            '{"success": true, "message": "Test communication working!"}');
      },
    );

    // Register command handler
    developer.registerExtension(
      'ext.secure_storage.command',
      (method, parameters) async {
        try {
          if (_globalStorageInstance != null) {
            await _handleStorageCommand(parameters, _globalStorageInstance!);
            return developer.ServiceExtensionResponse.result(
                '{"success": true}');
          } else {
            return developer.ServiceExtensionResponse.error(
              1,
              'No storage instance available',
            );
          }
        } catch (e, stackTrace) {
          return developer.ServiceExtensionResponse.error(
            2,
            'Command processing error: $e',
          );
        }
      },
    );

    // Register initial data request handler
    developer.registerExtension(
      'ext.secure_storage.requestInitialData',
      (method, parameters) async {
        if (_globalStorageInstance != null) {
          try {
            // Post initial data to DevTools
            await postSecureStorageToDevTools(_globalStorageInstance!);
            return developer.ServiceExtensionResponse.result(
                '{"success": true, "message": "Initial data posted successfully"}');
          } catch (e) {
            return developer.ServiceExtensionResponse.error(
              3,
              'Error posting initial data: $e',
            );
          }
        }

        return developer.ServiceExtensionResponse.error(
          1,
          'No storage instance available',
        );
      },
    );

    // Register refresh data handler (for manual data refresh)
    developer.registerExtension(
      'ext.secure_storage.refreshData',
      (method, parameters) async {
        if (_globalStorageInstance != null) {
          try {
            // Post fresh data to DevTools
            await postSecureStorageToDevTools(_globalStorageInstance!);
            return developer.ServiceExtensionResponse.result(
                '{"success": true, "message": "Data refreshed successfully"}');
          } catch (e) {
            return developer.ServiceExtensionResponse.error(
              3,
              'Error refreshing data: $e',
            );
          }
        }

        return developer.ServiceExtensionResponse.error(
          1,
          'No storage instance available',
        );
      },
    );

    // Mark extensions as registered
    _extensionsRegistered = true;
  } catch (e, stackTrace) {
    // Error handling without logging
  }
}

/// Helper function to compare two maps for equality
/* bool _mapsEqual(Map<String, String> map1, Map<String, String> map2) {
  if (map1.length != map2.length) return false;

  for (final key in map1.keys) {
    if (!map2.containsKey(key) || map1[key] != map2[key]) {
      return false;
    }
  }

  return true;
} */

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
  _globalStorageInstance = null;

  // Clear the global monitored keys to ensure clean state
  _globalMonitoredKeys.clear();
}

/// Manually register service extensions for debugging purposes.
///
/// Call this function if you want to ensure service extensions are registered
/// even without setting up the full listener system.
///
/// Example:
/// ```dart
/// if (kDebugMode) {
///   ensureServiceExtensionsRegistered();
/// }
/// ```
void ensureServiceExtensionsRegistered() {
  if (!kDebugMode) return;

  _registerCommandExtension();
}

/// Manually refreshes all secure storage data and posts it to DevTools.
///
/// This function is useful when you want to manually trigger a data refresh
/// without waiting for automatic updates or listeners.
///
/// Args:
///   [storage]: The Flutter `FlutterSecureStorage` instance from your app.
///
/// Example:
/// ```dart
/// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
/// import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';
///
/// void refreshStorageData() {
///   final storage = FlutterSecureStorage();
///   if (kDebugMode) {
///     refreshSecureStorageData(storage);
///   }
/// }
/// ```
Future<void> refreshSecureStorageData(FlutterSecureStorage storage) async {
  if (!kDebugMode) return;

  try {
    await postSecureStorageToDevTools(storage);
  } catch (e) {
    // Error handling without logging
  }
}

/// Diagnostic function to test if service extensions are working
///
/// Call this function to verify that the service extensions can be registered
/// and are working properly.
///
/// Example:
/// ```dart
/// if (kDebugMode) {
///   testServiceExtensions();
/// }
/// ```
void testServiceExtensions() {
  if (!kDebugMode) return;

  try {
    // Try to register a simple test extension
    developer.registerExtension(
      'ext.secure_storage.diagnostic',
      (method, parameters) async {
        return developer.ServiceExtensionResponse.result(
          '{"success": true, "message": "Service extensions are working!", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      },
    );

    // Also ensure our main extensions are registered
    _registerCommandExtension();
  } catch (e, stackTrace) {
    // Error handling without logging
  }
}
