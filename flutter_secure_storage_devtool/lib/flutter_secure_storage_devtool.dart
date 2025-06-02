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
      'Device info: ${deviceInfo['deviceName']} (${deviceInfo['deviceId']})',
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

    developer.log(
      'Flutter Secure Storage DevTool: Update posted for key "$key" with operation "$operation"',
      name: 'SecureStorageDevTool',
    );
  } catch (e) {
    developer.log(
      'Error posting secure storage update to DevTools: $e',
      name: 'SecureStorageDevTool',
      error: e,
    );
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
    developer.log(
      'Flutter Secure Storage DevTool: 🔄 Processing storage command: $command',
      name: 'SecureStorageDevTool',
    );

    final operation = command['operation'] as String?;
    final key = command['key'] as String?;
    final value =
        command.containsKey('value') ? command['value'] as String? : null;

    developer.log(
      'Flutter Secure Storage DevTool: Parsed command - Operation: $operation, Key: $key, Value: $value',
      name: 'SecureStorageDevTool',
    );

    // Validate required parameters based on operation
    if (operation == 'deleteAll') {
      // deleteAll doesn't need a key
      developer.log(
        'Flutter Secure Storage DevTool: ✅ DELETE ALL operation - no key required',
        name: 'SecureStorageDevTool',
      );
    } else if (key == null) {
      developer.log(
        'Flutter Secure Storage DevTool: ❌ Invalid command - missing key for operation "$operation"',
        name: 'SecureStorageDevTool',
      );
      return;
    }

    switch (operation) {
      case 'edit':
        if (value != null && key != null) {
          developer.log(
            'Flutter Secure Storage DevTool: 📝 Executing WRITE operation for key "$key" with value "$value"',
            name: 'SecureStorageDevTool',
          );
          await storage.write(key: key, value: value);
          developer.log(
            'Flutter Secure Storage DevTool: ✅ WRITE completed successfully for key "$key"',
            name: 'SecureStorageDevTool',
          );
          // Post update to DevTools
          postSecureStorageUpdateToDevTools(key, value, 'set');
        } else {
          developer.log(
            'Flutter Secure Storage DevTool: ❌ Edit command missing value or key',
            name: 'SecureStorageDevTool',
          );
        }
        break;
      case 'delete':
        if (key != null) {
          developer.log(
            'Flutter Secure Storage DevTool: 🗑️ Executing DELETE operation for key "$key"',
            name: 'SecureStorageDevTool',
          );
          await storage.delete(key: key);
          developer.log(
            'Flutter Secure Storage DevTool: ✅ DELETE completed successfully for key "$key"',
            name: 'SecureStorageDevTool',
          );
          // Post update to DevTools
          postSecureStorageUpdateToDevTools(key, null, 'delete');
        } else {
          developer.log(
            'Flutter Secure Storage DevTool: ❌ Delete command missing key',
            name: 'SecureStorageDevTool',
          );
        }
        break;
      case 'deleteAll':
        developer.log(
          'Flutter Secure Storage DevTool: 🗑️ Executing DELETE ALL operation',
          name: 'SecureStorageDevTool',
        );

        try {
          // Check what data exists before deletion
          final beforeData = await storage.readAll();
          developer.log(
            'Flutter Secure Storage DevTool: 📊 Data before deletion: ${beforeData.length} keys: ${beforeData.keys.toList()}',
            name: 'SecureStorageDevTool',
          );

          // Perform the delete all operation
          developer.log(
            'Flutter Secure Storage DevTool: 🔥 Calling storage.deleteAll()...',
            name: 'SecureStorageDevTool',
          );
          await storage.deleteAll();

          // Verify deletion worked
          final afterData = await storage.readAll();
          developer.log(
            'Flutter Secure Storage DevTool: 📊 Data after deletion: ${afterData.length} keys: ${afterData.keys.toList()}',
            name: 'SecureStorageDevTool',
          );

          if (afterData.isEmpty) {
            developer.log(
              'Flutter Secure Storage DevTool: ✅ DELETE ALL completed successfully - all data removed',
              name: 'SecureStorageDevTool',
            );
          } else {
            developer.log(
              'Flutter Secure Storage DevTool: ⚠️ DELETE ALL completed but ${afterData.length} keys still remain: ${afterData.keys.toList()}',
              name: 'SecureStorageDevTool',
            );

            // Try individual deletion as fallback
            developer.log(
              'Flutter Secure Storage DevTool: 🔄 Attempting individual deletion as fallback...',
              name: 'SecureStorageDevTool',
            );

            for (final key in afterData.keys) {
              try {
                await storage.delete(key: key);
                developer.log(
                  'Flutter Secure Storage DevTool: 🗑️ Deleted key: $key',
                  name: 'SecureStorageDevTool',
                );
              } catch (e) {
                developer.log(
                  'Flutter Secure Storage DevTool: ❌ Failed to delete key "$key": $e',
                  name: 'SecureStorageDevTool',
                );
              }
            }

            // Verify final state
            final finalData = await storage.readAll();
            developer.log(
              'Flutter Secure Storage DevTool: 📊 Final data after individual deletion: ${finalData.length} keys: ${finalData.keys.toList()}',
              name: 'SecureStorageDevTool',
            );
          }

          // Post update to DevTools (using special key to indicate all deleted)
          postSecureStorageUpdateToDevTools('*', null, 'deleteAll');
          // Also post fresh data to update the full view
          postSecureStorageToDevTools(storage);
        } catch (e, stackTrace) {
          developer.log(
            'Flutter Secure Storage DevTool: ❌ Error during DELETE ALL operation: $e',
            name: 'SecureStorageDevTool',
            error: e,
            stackTrace: stackTrace,
          );
          // Still post updates to show the current state
          postSecureStorageToDevTools(storage);
        }
        break;
      default:
        developer.log(
          'Flutter Secure Storage DevTool: ❌ Unknown command operation: $operation',
          name: 'SecureStorageDevTool',
        );
    }
  } catch (e) {
    developer.log(
      'Flutter Secure Storage DevTool: ❌ Error handling storage command: $e',
      name: 'SecureStorageDevTool',
      error: e,
    );
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

  final Set<String> _monitoredKeys = <String>{};

  // Helper function to post updates when any value changes
  void _onStorageChange(String key, String? value) {
    developer.log(
      'Flutter Secure Storage DevTool: Key "$key" changed, posting individual update',
      name: 'SecureStorageDevTool',
    );
    // Post only the specific update instead of all data
    postSecureStorageUpdateToDevTools(key, value, 'set');
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

        // Post full data update when new keys are found
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

  // Post initial data after a short delay to ensure DevTools extension is ready
  Timer(const Duration(milliseconds: 300), () async {
    try {
      await postSecureStorageToDevTools(storage);
      developer.log(
        'Flutter Secure Storage DevTool: Posted initial data to DevTools',
        name: 'SecureStorageDevTool',
      );
    } catch (e) {
      developer.log(
        'Error posting initial data: $e',
        name: 'SecureStorageDevTool',
        error: e,
      );
    }
  });

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

/// Registers the service extension for handling commands from DevTools
void _registerCommandExtension() {
  // Prevent double registration
  if (_extensionsRegistered) {
    developer.log(
      'Flutter Secure Storage DevTool: Service extensions already registered, skipping...',
      name: 'SecureStorageDevTool',
    );
    return;
  }

  try {
    developer.log(
      'Flutter Secure Storage DevTool: Attempting to register service extensions...',
      name: 'SecureStorageDevTool',
    );

    // Register test communication handler first
    developer.registerExtension(
      'ext.secure_storage.testCommunication',
      (method, parameters) async {
        developer.log(
          'Flutter Secure Storage DevTool: 🧪 TEST COMMUNICATION RECEIVED! Method: $method, Parameters: $parameters',
          name: 'SecureStorageDevTool',
        );
        return developer.ServiceExtensionResponse.result(
            '{"success": true, "message": "Test communication working!"}');
      },
    );

    // Register command handler
    developer.registerExtension(
      'ext.secure_storage.command',
      (method, parameters) async {
        developer.log(
          'Flutter Secure Storage DevTool: 📨 COMMAND RECEIVED! Method: $method',
          name: 'SecureStorageDevTool',
        );
        developer.log(
          'Flutter Secure Storage DevTool: 📦 Parameters: $parameters',
          name: 'SecureStorageDevTool',
        );
        developer.log(
          'Flutter Secure Storage DevTool: 📦 Parameters type: ${parameters.runtimeType}',
          name: 'SecureStorageDevTool',
        );
        developer.log(
          'Flutter Secure Storage DevTool: 📦 Parameters keys: ${parameters.keys.toList()}',
          name: 'SecureStorageDevTool',
        );
        developer.log(
          'Flutter Secure Storage DevTool: 📦 Parameters values: ${parameters.values.toList()}',
          name: 'SecureStorageDevTool',
        );

        try {
          if (_globalStorageInstance != null) {
            developer.log(
              'Flutter Secure Storage DevTool: ✅ Storage instance available, processing command...',
              name: 'SecureStorageDevTool',
            );
            await _handleStorageCommand(parameters, _globalStorageInstance!);
            developer.log(
              'Flutter Secure Storage DevTool: ✅ Command processed successfully!',
              name: 'SecureStorageDevTool',
            );
            return developer.ServiceExtensionResponse.result(
                '{"success": true}');
          } else {
            developer.log(
              'Flutter Secure Storage DevTool: ❌ No storage instance available for command',
              name: 'SecureStorageDevTool',
            );
            return developer.ServiceExtensionResponse.error(
              1,
              'No storage instance available',
            );
          }
        } catch (e, stackTrace) {
          developer.log(
            'Flutter Secure Storage DevTool: ❌ Error in command handler: $e',
            name: 'SecureStorageDevTool',
            error: e,
            stackTrace: stackTrace,
          );
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
        developer.log(
          'Flutter Secure Storage DevTool: Received initial data request - Method: $method, Parameters: $parameters',
          name: 'SecureStorageDevTool',
        );

        if (_globalStorageInstance != null) {
          // Post initial data to DevTools
          await postSecureStorageToDevTools(_globalStorageInstance!);
          return developer.ServiceExtensionResponse.result(
              '{"success": true, "message": "Initial data posted"}');
        }

        developer.log(
          'Flutter Secure Storage DevTool: No storage instance available for initial data request',
          name: 'SecureStorageDevTool',
        );
        return developer.ServiceExtensionResponse.error(
          1,
          'No storage instance available',
        );
      },
    );

    developer.log(
      'Flutter Secure Storage DevTool: ✅ Command and initial data extensions registered successfully',
      name: 'SecureStorageDevTool',
    );

    // Mark extensions as registered
    _extensionsRegistered = true;
  } catch (e, stackTrace) {
    developer.log(
      'Flutter Secure Storage DevTool: ❌ Error registering service extensions: $e',
      name: 'SecureStorageDevTool',
      error: e,
      stackTrace: stackTrace,
    );
  }
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
  _globalStorageInstance = null;
  developer.log(
    'Flutter Secure Storage DevTool: All listeners stopped',
    name: 'SecureStorageDevTool',
  );
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

  developer.log(
    'Flutter Secure Storage DevTool: 🔧 Manually ensuring service extensions are registered...',
    name: 'SecureStorageDevTool',
  );

  _registerCommandExtension();
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

  developer.log(
    'Flutter Secure Storage DevTool: 🧪 Testing service extensions registration...',
    name: 'SecureStorageDevTool',
  );

  try {
    // Try to register a simple test extension
    developer.registerExtension(
      'ext.secure_storage.diagnostic',
      (method, parameters) async {
        developer.log(
          'Flutter Secure Storage DevTool: 🎯 DIAGNOSTIC EXTENSION CALLED! This means service extensions are working!',
          name: 'SecureStorageDevTool',
        );
        return developer.ServiceExtensionResponse.result(
          '{"success": true, "message": "Service extensions are working!", "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
      },
    );

    developer.log(
      'Flutter Secure Storage DevTool: ✅ Diagnostic extension registered successfully',
      name: 'SecureStorageDevTool',
    );

    // Also ensure our main extensions are registered
    _registerCommandExtension();

    developer.log(
      'Flutter Secure Storage DevTool: 🚀 All service extensions should now be available',
      name: 'SecureStorageDevTool',
    );
  } catch (e, stackTrace) {
    developer.log(
      'Flutter Secure Storage DevTool: ❌ Error during service extension testing: $e',
      name: 'SecureStorageDevTool',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
