/// Model to represent Flutter Secure Storage data
class SecureStorageData {
  final Map<String, dynamic> storageData;
  final String deviceId;
  final String deviceName;
  final DateTime timestamp;

  SecureStorageData({
    required this.storageData,
    required this.deviceId,
    required this.deviceName,
    required this.timestamp,
  });

  factory SecureStorageData.fromJson(dynamic jsonData) {
    try {
      final json = jsonData as Map<String, dynamic>;
      final storageData = <String, dynamic>{};
      if (json.containsKey('storageData') && json['storageData'] != null) {
        final data = json['storageData'];
        if (data is Map) {
          storageData.addAll(Map<String, dynamic>.from(data));
        }
      }

      final deviceId = json['deviceId'] as String? ?? 'unknown';
      final deviceName = json['deviceName'] as String? ?? 'Unknown Device';

      DateTime timestamp;
      if (json.containsKey('timestamp') && json['timestamp'] != null) {
        try {
          final timestampValue = json['timestamp'];
          if (timestampValue is int) {
            timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue);
          } else {
            timestamp = DateTime.now();
          }
        } catch (e) {
          timestamp = DateTime.now();
        }
      } else {
        timestamp = DateTime.now();
      }

      return SecureStorageData(
        storageData: storageData,
        deviceId: deviceId,
        deviceName: deviceName,
        timestamp: timestamp,
      );
    } catch (e) {
      // Return a fallback data if parsing fails
      return SecureStorageData(
        storageData: {'error': 'Failed to parse storage data'},
        deviceId: 'error_parsing',
        deviceName: 'Error Parsing Device',
        timestamp: DateTime.now(),
      );
    }
  }
}

/// Model to represent a Flutter Secure Storage update event
class SecureStorageUpdate {
  final String key;
  final String? value;
  final String operation; // 'set', 'delete', 'clear'
  final String deviceId;
  final String deviceName;
  final DateTime timestamp;

  SecureStorageUpdate({
    required this.key,
    required this.value,
    required this.operation,
    required this.deviceId,
    required this.deviceName,
    required this.timestamp,
  });

  factory SecureStorageUpdate.fromJson(dynamic jsonData) {
    try {
      final json = jsonData as Map<String, dynamic>;
      final key = json['key'] as String? ?? 'unknown_key';
      final value = json['value'] as String?;
      final operation = json['operation'] as String? ?? 'set';
      final deviceId = json['deviceId'] as String? ?? 'unknown';
      final deviceName = json['deviceName'] as String? ?? 'Unknown Device';

      DateTime timestamp;
      if (json.containsKey('timestamp') && json['timestamp'] != null) {
        try {
          final timestampValue = json['timestamp'];
          if (timestampValue is int) {
            timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue);
          } else {
            timestamp = DateTime.now();
          }
        } catch (e) {
          timestamp = DateTime.now();
        }
      } else {
        timestamp = DateTime.now();
      }

      return SecureStorageUpdate(
        key: key,
        value: value,
        operation: operation,
        deviceId: deviceId,
        deviceName: deviceName,
        timestamp: timestamp,
      );
    } catch (e) {
      // Return a fallback update if parsing fails
      return SecureStorageUpdate(
        key: 'error_parsing',
        value: 'Failed to parse update data',
        operation: 'error',
        deviceId: 'error_parsing',
        deviceName: 'Error Parsing Device',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Returns a color representing the operation type
  String get operationIcon {
    switch (operation) {
      case 'set':
        return '📝'; // Edit/write
      case 'delete':
        return '🗑️'; // Delete
      case 'clear':
        return '🧹'; // Clear all
      default:
        return '❓'; // Unknown
    }
  }

  /// Returns a human-readable description of the operation
  String get operationDescription {
    switch (operation) {
      case 'set':
        return 'Updated';
      case 'delete':
        return 'Deleted';
      case 'clear':
        return 'Cleared';
      default:
        return 'Unknown operation';
    }
  }
}
