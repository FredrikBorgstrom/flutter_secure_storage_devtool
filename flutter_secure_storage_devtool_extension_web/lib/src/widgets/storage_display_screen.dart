import 'package:devtools_extensions/api.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../models/secure_storage_data.dart';
import '../services/storage_service.dart';
import 'settings_tab.dart';
import 'storage_card.dart';

/// The main screen for displaying Flutter Secure Storage data
class StorageDisplayScreen extends StatefulWidget {
  const StorageDisplayScreen({super.key});

  @override
  State<StorageDisplayScreen> createState() => _StorageDisplayScreenState();
}

class _StorageDisplayScreenState extends State<StorageDisplayScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<SecureStorageData> _storageDataList = [];
  bool _showNewestOnTop = false;
  bool _clearOnReload = true;
  bool _hideNullValues = false;
  String _selectedDeviceId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    setState(() {
      _showNewestOnTop = settings['showNewestOnTop'] ?? false;
      _clearOnReload = settings['clearOnReload'] ?? true;
      _hideNullValues = settings['hideNullValues'] ?? false;
    });
  }

  void _setupEventListeners() {
    extensionManager.registerEventHandler(DevToolsExtensionEventType.unknown, (
      event,
    ) {
      // Custom events are mapped to 'unknown' type, so we need to check the raw event
      if (event.source != null && event.source!.contains('SecureStorage')) {
        _handleStorageEvent(event.data as Map<String, dynamic>);
      }
    });
  }

  void _handleStorageEvent(Map<String, dynamic> data) {
    final storageData = SecureStorageData.fromJson(data);

    setState(() {
      if (_clearOnReload && _storageDataList.isEmpty) {
        // Clear the list if it's empty and clearOnReload is true
        _storageDataList.clear();
      }

      // Add the new data
      if (_showNewestOnTop) {
        _storageDataList.insert(0, storageData);
      } else {
        _storageDataList.add(storageData);
      }

      // Keep only the latest 100 entries
      if (_storageDataList.length > 100) {
        _storageDataList.removeLast();
      }

      // Set the selected device to the latest one if none is selected
      if (_selectedDeviceId.isEmpty) {
        _selectedDeviceId = storageData.deviceId;
      }
    });
  }

  void _updateSettings({
    required bool showNewestOnTop,
    required bool clearOnReload,
    required bool hideNullValues,
  }) {
    setState(() {
      _showNewestOnTop = showNewestOnTop;
      _clearOnReload = clearOnReload;
      _hideNullValues = hideNullValues;
    });

    StorageService.saveSettings(
      showNewestOnTop: showNewestOnTop,
      clearOnReload: clearOnReload,
      hideNullValues: hideNullValues,
    );
  }

  void _clearStorageData() {
    setState(() {
      _storageDataList.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Secure Storage DevTool'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Storage Data'), Tab(text: 'Settings')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear all data',
            onPressed: _clearStorageData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Storage Data Tab
          _buildStorageDataTab(),

          // Settings Tab
          SettingsTab(
            showNewestOnTop: _showNewestOnTop,
            clearOnReload: _clearOnReload,
            hideNullValues: _hideNullValues,
            onSettingsChanged: _updateSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildStorageDataTab() {
    if (_storageDataList.isEmpty) {
      return const Center(child: Text('No storage data received yet.'));
    }

    // Group data by device
    final Map<String, List<SecureStorageData>> deviceGroups = {};
    for (final data in _storageDataList) {
      if (!deviceGroups.containsKey(data.deviceId)) {
        deviceGroups[data.deviceId] = [];
      }
      deviceGroups[data.deviceId]!.add(data);
    }

    // If no device is selected, select the first one
    if (_selectedDeviceId.isEmpty && deviceGroups.isNotEmpty) {
      _selectedDeviceId = deviceGroups.keys.first;
    }

    return Column(
      children: [
        // Device selector
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String>(
            value: _selectedDeviceId,
            isExpanded: true,
            hint: const Text('Select a device'),
            items:
                deviceGroups.keys.map((deviceId) {
                  final deviceName = deviceGroups[deviceId]!.first.deviceName;
                  return DropdownMenuItem<String>(
                    value: deviceId,
                    child: Text('$deviceName ($deviceId)'),
                  );
                }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedDeviceId = value;
                });
              }
            },
          ),
        ),

        // Storage data list
        Expanded(
          child: ListView.builder(
            itemCount: deviceGroups[_selectedDeviceId]?.length ?? 0,
            itemBuilder: (context, index) {
              final data = deviceGroups[_selectedDeviceId]![index];
              return StorageCard(data: data, hideNullValues: _hideNullValues);
            },
          ),
        ),
      ],
    );
  }
}
