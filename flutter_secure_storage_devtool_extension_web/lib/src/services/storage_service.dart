import 'dart:async';

import 'package:web/web.dart' as web;

import '../constants.dart';

/// Service for handling local storage operations (Settings Only)
class StorageService {
  /// Loads user settings from local storage
  static Future<Map<String, bool>> loadSettings() async {
    try {
      final showNewestOnTopStr = web.window.localStorage.getItem(
        showNewestOnTopKey,
      );

      final showNewestOnTop = showNewestOnTopStr == 'true';

      return {'showNewestOnTop': showNewestOnTop};
    } catch (e) {
      // Return defaults
      return {'showNewestOnTop': false};
    }
  }

  /// Saves user settings to local storage
  static Future<void> saveSettings({required bool showNewestOnTop}) async {
    try {
      web.window.localStorage.setItem(
        showNewestOnTopKey,
        showNewestOnTop.toString(),
      );
    } catch (e) {}
  }
}
