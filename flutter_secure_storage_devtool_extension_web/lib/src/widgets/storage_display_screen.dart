import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' show Event;

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

  // VM service subscription for receiving events
  StreamSubscription<Event>? _eventSubscription;
  bool _acceptingMessages = false;
  Timer? _acceptMessagesTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettingsAndInitListener();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _acceptMessagesTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndInitListener() async {
    await _loadSettings();
    _acceptingMessages = !_clearOnReload;
    _initServiceListener();
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    setState(() {
      _showNewestOnTop = settings['showNewestOnTop'] ?? false;
      _clearOnReload = settings['clearOnReload'] ?? true;
      _hideNullValues = settings['hideNullValues'] ?? false;
    });
  }

  Future<void> _initServiceListener() async {
    try {
      print('🔧 Initializing VM service listener for SecureStorage...');
      final vmService = await serviceManager.onServiceAvailable;

      // Register our service with the VM service
      await vmService.registerService(
        'SecureStorage',
        'ext.secure_storage.data',
      );

      print('✅ Registered SecureStorage service with VM service');

      // Listen for extension events
      _eventSubscription = vmService.onExtensionEvent.listen(
        (event) {
          print('📨 Received VM extension event:');
          print('  - extensionKind: ${event.extensionKind}');
          print('  - extensionData: ${event.extensionData}');

          if (event.extensionKind == 'SecureStorage' ||
              event.extensionKind == 'ext.secure_storage.data') {
            print('✅ Processing SecureStorage event!');
            _handleStorageEvent(event);
          } else {
            print('❌ Ignoring event with kind: ${event.extensionKind}');
          }
        },
        onError: (error) {
          print('❌ VM service event error: $error');
        },
        onDone: () {
          print('🔚 VM service event stream closed');
        },
      );

      // Set up acceptance timing
      if (_clearOnReload) {
        _acceptMessagesTimer?.cancel();
        _acceptMessagesTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            _acceptingMessages = true;
            print('✅ Now accepting SecureStorage messages');
          }
        });
      } else {
        _acceptingMessages = true;
        print('✅ Accepting SecureStorage messages immediately');
      }

      print('🚀 VM service listener initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Error initializing VM service listener: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _handleStorageEvent(Event event) {
    if (!_acceptingMessages) {
      print('⏳ Ignoring SecureStorage event (not accepting yet)');
      return;
    }

    try {
      print('🔄 Processing SecureStorage event data...');
      final data = event.extensionData?.data as Map<String, dynamic>?;
      if (data == null) {
        print('❌ No extension data found in event');
        return;
      }

      print('📦 Event data: $data');
      final storageData = SecureStorageData.fromJson(data);

      setState(() {
        if (_clearOnReload && _storageDataList.isEmpty) {
          _storageDataList.clear();
        }

        if (_showNewestOnTop) {
          _storageDataList.insert(0, storageData);
        } else {
          _storageDataList.add(storageData);
        }

        if (_storageDataList.length > 100) {
          _storageDataList.removeLast();
        }

        if (_selectedDeviceId.isEmpty) {
          _selectedDeviceId = storageData.deviceId;
        }
      });

      print('✅ SecureStorage data added to UI!');
    } catch (e, stackTrace) {
      print('❌ Error processing SecureStorage event: $e');
      print('Stack trace: $stackTrace');
    }
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
