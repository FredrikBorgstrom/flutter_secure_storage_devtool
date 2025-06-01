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

  factory SecureStorageData.fromJson(Map<String, dynamic> json) {
    try {
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
