import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' show Event;

import '../models/secure_storage_data.dart';
import '../services/storage_service.dart';
import 'settings_tab.dart';
import 'storage_card.dart';
import 'storage_update_card.dart';

/// The main screen for displaying Flutter Secure Storage data
class StorageDisplayScreen extends StatefulWidget {
  const StorageDisplayScreen({super.key});

  @override
  State<StorageDisplayScreen> createState() => _StorageDisplayScreenState();
}

class _StorageDisplayScreenState extends State<StorageDisplayScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<SecureStorageData> _allDataList = [];
  final List<SecureStorageUpdate> _updatesList = [];
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
    _tabController = TabController(length: 3, vsync: this);
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

      // Register our services with the VM service
      await vmService.registerService(
        'SecureStorage',
        'ext.secure_storage.data',
      );
      await vmService.registerService(
        'SecureStorageUpdate',
        'ext.secure_storage.update',
      );

      print('✅ Registered SecureStorage services with VM service');

      // Listen for extension events
      _eventSubscription = vmService.onExtensionEvent.listen(
        (event) {
          // print('📨 Received VM extension event:');
          // print('  - extensionKind: ${event.extensionKind}');
          // print('  - extensionData: ${event.extensionData}');

          if (event.extensionKind == 'SecureStorage' ||
              event.extensionKind == 'ext.secure_storage.data') {
            // print('✅ Processing SecureStorage full data event!');
            _handleFullDataEvent(event);
          } else if (event.extensionKind == 'SecureStorageUpdate' ||
              event.extensionKind == 'ext.secure_storage.update') {
            print('✅ Processing SecureStorageUpdate event!');
            _handleUpdateEvent(event);
          } else {
            // print('❌ Ignoring event with kind: ${event.extensionKind}');
          }
        },
        onError: (error) {
          print('❌ VM service event error: $error');
        },
        onDone: () {
          print('🔚 VM service event stream closed');
        },
      );

      // Always start accepting messages immediately for initial data
      _acceptingMessages = true;
      print('✅ Accepting SecureStorage messages immediately');

      // Set up delayed acceptance for clearing on reload
      if (_clearOnReload) {
        _acceptMessagesTimer?.cancel();
        _acceptMessagesTimer = Timer(const Duration(milliseconds: 100), () {
          if (mounted) {
            // Clear data after a short delay, but keep accepting new messages
            setState(() {
              _allDataList.clear();
              _updatesList.clear();
            });
            print('🧹 Cleared data after reload delay');
          }
        });
      }

      // Request initial data after a small delay to ensure extension is ready
      Timer(const Duration(milliseconds: 200), () async {
        try {
          // Try to trigger initial data by calling a method that requests it
          await vmService.callServiceExtension(
            'ext.secure_storage.requestInitialData',
            args: <String, dynamic>{},
          );
          print('📡 Requested initial storage data');
        } catch (e) {
          print(
            'ℹ️ Could not request initial data (this is normal if the host app doesn\'t support it): $e',
          );
        }
      });

      print('🚀 VM service listener initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Error initializing VM service listener: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _handleFullDataEvent(Event event) {
    if (!_acceptingMessages) {
      print('⏳ Ignoring SecureStorage full data event (not accepting yet)');
      return;
    }

    try {
      print('🔄 Processing SecureStorage full data event...');
      final data = event.extensionData?.data;
      if (data == null) {
        print('❌ No extension data found in full data event');
        return;
      }

      print('📦 Full data event: $data');
      final storageData = SecureStorageData.fromJson(data);

      setState(() {
        // Only clear existing data if this is the first data and clearOnReload is true
        if (_clearOnReload && _allDataList.isEmpty) {
          _allDataList.clear();
        }

        if (_showNewestOnTop) {
          _allDataList.insert(0, storageData);
        } else {
          _allDataList.add(storageData);
        }

        if (_allDataList.length > 50) {
          if (_showNewestOnTop) {
            _allDataList.removeLast();
          } else {
            _allDataList.removeAt(0);
          }
        }

        if (_selectedDeviceId.isEmpty) {
          _selectedDeviceId = storageData.deviceId;
        }
      });

      print(
        '✅ SecureStorage full data added to UI! (${_allDataList.length} total snapshots)',
      );
    } catch (e, stackTrace) {
      print('❌ Error processing SecureStorage full data event: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _handleUpdateEvent(Event event) {
    if (!_acceptingMessages) {
      print('⏳ Ignoring SecureStorage update event (not accepting yet)');
      return;
    }

    try {
      print('🔄 Processing SecureStorage update event...');
      final data = event.extensionData?.data;
      if (data == null) {
        print('❌ No extension data found in update event');
        return;
      }

      print('📦 Update event: $data');
      final updateData = SecureStorageUpdate.fromJson(data);

      setState(() {
        if (_showNewestOnTop) {
          _updatesList.insert(0, updateData);
        } else {
          _updatesList.add(updateData);
        }

        if (_updatesList.length > 100) {
          if (_showNewestOnTop) {
            _updatesList.removeLast();
          } else {
            _updatesList.removeAt(0);
          }
        }

        if (_selectedDeviceId.isEmpty) {
          _selectedDeviceId = updateData.deviceId;
        }
      });

      print('✅ SecureStorage update added to UI!');
    } catch (e, stackTrace) {
      print('❌ Error processing SecureStorage update event: $e');
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

  void _clearAllData() {
    setState(() {
      _allDataList.clear();
      _updatesList.clear();
    });
  }

  void _clearStorageData() {
    setState(() {
      _allDataList.clear();
    });
  }

  void _clearUpdates() {
    setState(() {
      _updatesList.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Secure Storage DevTool'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All Data (${_allDataList.length})'),
            Tab(text: 'Updates (${_updatesList.length})'),
            const Tab(text: 'Settings'),
          ],
        ),
        actions: [
          // Test button for debugging VM service communication
          TextButton(
            onPressed: _testVMServiceCommunication,
            child: const Text('Test VM Service'),
          ),
          // Diagnostic test button
          TextButton(
            onPressed: _testDiagnosticExtension,
            child: const Text('Test Extensions'),
          ),
          // Create Key button
          TextButton(
            onPressed: _showCreateKeyDialog,
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Create Key'),
          ),
          // Delete All button
          TextButton(
            onPressed: _showDeleteAllDialog,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _clearAllData();
                  break;
                case 'clear_data':
                  _clearStorageData();
                  break;
                case 'clear_updates':
                  _clearUpdates();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Text('Clear All'),
                  ),
                  const PopupMenuItem(
                    value: 'clear_data',
                    child: Text('Clear Data'),
                  ),
                  const PopupMenuItem(
                    value: 'clear_updates',
                    child: Text('Clear Updates'),
                  ),
                ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All Data Tab
          _buildAllDataTab(),

          // Updates Tab
          _buildUpdatesTab(),

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

  Widget _buildAllDataTab() {
    if (_allDataList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storage, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No storage data received yet.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'This tab shows complete snapshots of your secure storage.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _requestInitialData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Request Data'),
            ),
          ],
        ),
      );
    }

    // Show all data from all devices directly
    return ListView.builder(
      itemCount: _allDataList.length,
      itemBuilder: (context, index) {
        final data = _allDataList[index];
        return StorageCard(data: data, hideNullValues: _hideNullValues);
      },
    );
  }

  Widget _buildUpdatesTab() {
    if (_updatesList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.update, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No updates received yet.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'This tab shows individual key-value changes as they happen.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group updates by device for the updates tab
    final Map<String, List<SecureStorageUpdate>> deviceGroups = {};
    for (final update in _updatesList) {
      if (!deviceGroups.containsKey(update.deviceId)) {
        deviceGroups[update.deviceId] = [];
      }
      deviceGroups[update.deviceId]!.add(update);
    }

    // If no device is selected, select the first one
    if (_selectedDeviceId.isEmpty && deviceGroups.isNotEmpty) {
      _selectedDeviceId = deviceGroups.keys.first;
    }

    return Column(
      children: [
        // Device selector (only for updates tab when there are multiple devices)
        if (deviceGroups.length > 1)
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

        // Updates list
        Expanded(
          child: ListView.builder(
            itemCount:
                deviceGroups.length > 1
                    ? (deviceGroups[_selectedDeviceId]?.length ?? 0)
                    : _updatesList.length,
            itemBuilder: (context, index) {
              final update =
                  deviceGroups.length > 1
                      ? deviceGroups[_selectedDeviceId]![index]
                      : _updatesList[index];
              return StorageUpdateCard(update: update);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _requestInitialData() async {
    try {
      final vmService = await serviceManager.onServiceAvailable;

      // Find the correct isolate that has our extensions
      print('🔍 Finding isolate with requestInitialData extension...');
      final vm = await vmService.getVM();
      String? targetIsolateId;

      if (vm.isolates?.isNotEmpty == true) {
        for (final isolateRef in vm.isolates!) {
          try {
            final isolateDetails = await vmService.getIsolate(isolateRef.id!);
            final availableExtensions = isolateDetails.extensionRPCs ?? [];

            if (availableExtensions.contains(
              'ext.secure_storage.requestInitialData',
            )) {
              targetIsolateId = isolateRef.id;
              print('🎯 Found target isolate: ${isolateRef.id}');
              break;
            }
          } catch (e) {
            print('⚠️ Error checking isolate ${isolateRef.id}: $e');
          }
        }
      }

      if (targetIsolateId == null) {
        throw Exception(
          'No isolate found with ext.secure_storage.requestInitialData extension',
        );
      }

      await vmService.callServiceExtension(
        'ext.secure_storage.requestInitialData',
        isolateId: targetIsolateId,
        args: <String, dynamic>{},
      );
      print('📡 Manually requested initial storage data');
    } catch (e) {
      print('❌ Error requesting initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not request data. Make sure your app is running with the storage listener active.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _testVMServiceCommunication() async {
    try {
      print('🧪 Testing VM Service communication...');
      final vmService = await serviceManager.onServiceAvailable;
      print('✅ VM Service obtained for test');

      // Get detailed information about available extensions
      print('🔍 Getting VM and isolate information...');
      final vm = await vmService.getVM();
      print('📋 VM info: ${vm.name}, version: ${vm.version}');
      print('📋 Number of isolates: ${vm.isolates?.length ?? 0}');

      String? targetIsolateId;

      if (vm.isolates?.isNotEmpty == true) {
        for (int i = 0; i < vm.isolates!.length; i++) {
          final isolateRef = vm.isolates![i];
          print('📋 Isolate $i: ${isolateRef.name} (${isolateRef.id})');

          try {
            final isolateDetails = await vmService.getIsolate(isolateRef.id!);
            final availableExtensions = isolateDetails.extensionRPCs ?? [];
            print(
              '🏷️ Isolate $i extensions (${availableExtensions.length}): $availableExtensions',
            );

            // Check specifically for our extensions
            final hasTestComm = availableExtensions.contains(
              'ext.secure_storage.testCommunication',
            );
            final hasCommand = availableExtensions.contains(
              'ext.secure_storage.command',
            );
            final hasDiagnostic = availableExtensions.contains(
              'ext.secure_storage.diagnostic',
            );
            final hasRequestData = availableExtensions.contains(
              'ext.secure_storage.requestInitialData',
            );

            print('✅ Has testCommunication: $hasTestComm');
            print('✅ Has command: $hasCommand');
            print('✅ Has diagnostic: $hasDiagnostic');
            print('✅ Has requestInitialData: $hasRequestData');

            // If this isolate has our extensions, use it as the target
            if (hasTestComm && hasCommand && hasDiagnostic && hasRequestData) {
              targetIsolateId = isolateRef.id;
              print(
                '🎯 Found target isolate for our extensions: ${isolateRef.id}',
              );
            }
          } catch (e) {
            print('❌ Error getting isolate $i details: $e');
          }
        }
      }

      if (targetIsolateId == null) {
        throw Exception('No isolate found with our secure storage extensions');
      }

      // Try the test communication with the correct isolate
      try {
        print(
          '📡 Attempting to call ext.secure_storage.testCommunication on isolate $targetIsolateId...',
        );
        final response = await vmService.callServiceExtension(
          'ext.secure_storage.testCommunication',
          isolateId: targetIsolateId,
          args: <String, dynamic>{},
        );

        print('✅ Test VM Service communication successful');
        print('📬 Response: ${response.json}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('VM Service test successful: ${response.json}'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Failed to call testCommunication: $e');

        // Try calling a known Flutter extension to verify VM service works
        try {
          print('🔧 Testing with known Flutter extension on same isolate...');
          final flutterResponse = await vmService.callServiceExtension(
            'ext.flutter.debugPaint',
            isolateId: targetIsolateId,
            args: <String, dynamic>{},
          );
          print('✅ Flutter extension call successful: ${flutterResponse.json}');
        } catch (flutterError) {
          print('❌ Even Flutter extensions fail: $flutterError');
        }

        rethrow;
      }
    } catch (e, stackTrace) {
      print('❌ Error testing VM Service communication: $e');
      print('📚 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('VM Service test failed: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testDiagnosticExtension() async {
    try {
      print('🧪 Testing Extensions...');
      final vmService = await serviceManager.onServiceAvailable;
      print('✅ VM Service obtained for test');

      // Find the correct isolate that has our extensions
      print('🔍 Finding isolate with diagnostic extension...');
      final vm = await vmService.getVM();
      String? targetIsolateId;

      if (vm.isolates?.isNotEmpty == true) {
        for (final isolateRef in vm.isolates!) {
          try {
            final isolateDetails = await vmService.getIsolate(isolateRef.id!);
            final availableExtensions = isolateDetails.extensionRPCs ?? [];

            if (availableExtensions.contains('ext.secure_storage.diagnostic')) {
              targetIsolateId = isolateRef.id;
              print('🎯 Found target isolate: ${isolateRef.id}');
              break;
            }
          } catch (e) {
            print('⚠️ Error checking isolate ${isolateRef.id}: $e');
          }
        }
      }

      if (targetIsolateId == null) {
        throw Exception(
          'No isolate found with ext.secure_storage.diagnostic extension',
        );
      }

      final response = await vmService.callServiceExtension(
        'ext.secure_storage.diagnostic',
        isolateId: targetIsolateId,
        args: <String, dynamic>{},
      );

      print('✅ Test Extensions successful');
      print('📬 Response: ${response.json}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extensions test successful: ${response.json}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error testing Extensions: $e');
      print('📚 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extensions test failed: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteAllDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Make user explicitly choose
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Confirm Deletion'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete ALL secure storage data?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('This action cannot be undone.'),
              SizedBox(height: 8),
              Text(
                'All keys and values will be permanently removed from secure storage.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteAllStorageData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAllStorageData() async {
    try {
      print('🗑️ Starting delete all storage command...');
      final vmService = await serviceManager.onServiceAvailable;

      // Find the correct isolate that has our extensions
      print('🔍 Finding isolate with command extension...');
      final vm = await vmService.getVM();
      String? targetIsolateId;

      if (vm.isolates?.isNotEmpty == true) {
        for (final isolateRef in vm.isolates!) {
          try {
            final isolateDetails = await vmService.getIsolate(isolateRef.id!);
            final availableExtensions = isolateDetails.extensionRPCs ?? [];

            if (availableExtensions.contains('ext.secure_storage.command')) {
              targetIsolateId = isolateRef.id;
              print('🎯 Found target isolate: ${isolateRef.id}');
              break;
            }
          } catch (e) {
            print('⚠️ Error checking isolate ${isolateRef.id}: $e');
          }
        }
      }

      if (targetIsolateId == null) {
        throw Exception(
          'No isolate found with ext.secure_storage.command extension',
        );
      }

      // Send deleteAll command
      final commandData = {'operation': 'deleteAll'};

      print(
        '📡 Calling service extension: ext.secure_storage.command for deleteAll',
      );
      final response = await vmService.callServiceExtension(
        'ext.secure_storage.command',
        isolateId: targetIsolateId,
        args: commandData,
      );

      print('✅ Delete all command sent successfully!');
      print('📬 Response: ${response.json}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All secure storage data deleted successfully'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error sending delete all command: $e');
      print('📚 Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete all data: $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCreateKeyDialog() async {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add, color: Colors.green),
              SizedBox(width: 8),
              Text('Create New Key'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    border: OutlineInputBorder(),
                    hintText: 'Enter the key name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Key cannot be empty';
                    }
                    return null;
                  },
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: valueController,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    border: OutlineInputBorder(),
                    hintText: 'Enter the value',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Value cannot be empty';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop();
                  await _createStorageKey(
                    keyController.text.trim(),
                    valueController.text.trim(),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createStorageKey(String key, String value) async {
    try {
      print(
        '🔑 Starting create key command for key: "$key" with value: "$value"',
      );
      final vmService = await serviceManager.onServiceAvailable;

      // Find the correct isolate that has our extensions
      print('🔍 Finding isolate with command extension...');
      final vm = await vmService.getVM();
      String? targetIsolateId;

      if (vm.isolates?.isNotEmpty == true) {
        for (final isolateRef in vm.isolates!) {
          try {
            final isolateDetails = await vmService.getIsolate(isolateRef.id!);
            final availableExtensions = isolateDetails.extensionRPCs ?? [];

            if (availableExtensions.contains('ext.secure_storage.command')) {
              targetIsolateId = isolateRef.id;
              print('🎯 Found target isolate: ${isolateRef.id}');
              break;
            }
          } catch (e) {
            print('⚠️ Error checking isolate ${isolateRef.id}: $e');
          }
        }
      }

      if (targetIsolateId == null) {
        throw Exception(
          'No isolate found with ext.secure_storage.command extension',
        );
      }

      // Send create/edit command
      final commandData = {'operation': 'edit', 'key': key, 'value': value};

      print(
        '📡 Calling service extension: ext.secure_storage.command for create',
      );
      final response = await vmService.callServiceExtension(
        'ext.secure_storage.command',
        isolateId: targetIsolateId,
        args: commandData,
      );

      print('✅ Create key command sent successfully!');
      print('📬 Response: ${response.json}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Key "$key" created successfully'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error sending create key command: $e');
      print('📚 Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create key "$key": $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
