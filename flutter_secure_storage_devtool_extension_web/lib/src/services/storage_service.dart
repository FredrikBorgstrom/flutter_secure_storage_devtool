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
      final clearOnReloadStr = web.window.localStorage.getItem(
        clearOnReloadKey,
      );
      final hideNullValuesStr = web.window.localStorage.getItem(
        hideNullValuesKey,
      );

      final showNewestOnTop = showNewestOnTopStr == 'true';
      final clearOnReload = clearOnReloadStr != 'false';
      final hideNullValues = hideNullValuesStr != 'false';

      return {
        'showNewestOnTop': showNewestOnTop,
        'clearOnReload': clearOnReload,
        'hideNullValues': hideNullValues,
      };
    } catch (e) {
      // Return defaults
      return {
        'showNewestOnTop': false,
        'clearOnReload': true,
        'hideNullValues': false,
      };
    }
  }

  /// Saves user settings to local storage
  static Future<void> saveSettings({
    required bool showNewestOnTop,
    required bool clearOnReload,
    required bool hideNullValues,
  }) async {
    try {
      web.window.localStorage.setItem(
        showNewestOnTopKey,
        showNewestOnTop.toString(),
      );
      web.window.localStorage.setItem(
        clearOnReloadKey,
        clearOnReload.toString(),
      );
      web.window.localStorage.setItem(
        hideNullValuesKey,
        hideNullValues.toString(),
      );
    } catch (e) {}
  }
}
