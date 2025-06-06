import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart' show Event;

import '../models/secure_storage_data.dart';
import '../services/storage_service.dart';
import 'settings_tab.dart';
import 'storage_record_card.dart';

/// The main screen for displaying Flutter Secure Storage data
class StorageDisplayScreen extends StatefulWidget {
  const StorageDisplayScreen({super.key});

  @override
  State<StorageDisplayScreen> createState() => _StorageDisplayScreenState();
}

class _StorageDisplayScreenState extends State<StorageDisplayScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SecureStorageData> _allDataList = [];
  List<SecureStorageUpdate> _updatesList = [];
  bool _showNewestOnTop = false;
  String _selectedDeviceId = '';

  // Track expanded records
  Set<String> _expandedRecords = <String>{};
  Set<String> _expandedUpdateRecords = <String>{};

  // VM service subscription for receiving events
  StreamSubscription<Event>? _eventSubscription;
  bool _acceptingMessages = false;
  Timer? _acceptMessagesTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Always clear updates and data lists on app restart - ensure they never persist between sessions
    _updatesList = [];
    _allDataList = [];
    print('🧹 Cleared updates and data lists on app restart');

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

    // Initialize _acceptingMessages to false - this is key to prevent replayed events
    _acceptingMessages = false;

    _initServiceListener();
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    setState(() {
      _showNewestOnTop = settings['showNewestOnTop'] ?? false;
    });
  }

  Future<void> _initServiceListener() async {
    try {
      print('🔧 Initializing Extension event listener for SecureStorage...');
      final vmService = await serviceManager.onServiceAvailable;

      // Listen for Extension events (sent via developer.postEvent)
      _eventSubscription = vmService.onExtensionEvent.listen(
        (event) {
          print('📨 Received Extension event:');
          print('  - extensionKind: ${event.extensionKind}');
          print('  - extensionData: ${event.extensionData}');

          // Handle events based on the extension kind from developer.postEvent
          if (event.extensionKind == 'SecureStorage') {
            print('✅ Processing SecureStorage full data event!');
            _handleFullDataEvent(event);
          } else if (event.extensionKind == 'SecureStorageUpdate') {
            print('✅ Processing SecureStorageUpdate event!');
            _handleUpdateEvent(event);
          } else {
            print('❌ Ignoring event with kind: ${event.extensionKind}');
          }
        },
        onError: (error) {
          print('❌ Extension event error: $error');
        },
        onDone: () {
          print('🔚 Extension event stream closed');
        },
      );

      // Start timer to delay accepting messages - this prevents processing replayed events
      _acceptMessagesTimer?.cancel();
      _acceptMessagesTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          print('✅ Timer completed - now accepting SecureStorage messages');
          _acceptingMessages = true;
        }
      });

      print(
        '🚀 Extension event listener initialized - timer started for 500ms',
      );
    } catch (e, stackTrace) {
      print('❌ Error initializing Extension event listener: $e');
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
        // Add update to the updates list based on sorting preference
        _updatesList.add(updateData);

        // Sort the updates list by timestamp
        _updatesList.sort((a, b) {
          if (_showNewestOnTop) {
            return b.timestamp.compareTo(a.timestamp); // Newest first
          } else {
            return a.timestamp.compareTo(b.timestamp); // Oldest first
          }
        });

        // Keep only the latest 100 updates
        if (_updatesList.length > 100) {
          if (_showNewestOnTop) {
            _updatesList = _updatesList.take(100).toList();
          } else {
            _updatesList =
                _updatesList.skip(_updatesList.length - 100).toList();
          }
        }

        if (_selectedDeviceId.isEmpty) {
          _selectedDeviceId = updateData.deviceId;
        }

        // Update the specific key in the All Data list WITHOUT doing a full refresh
        if (_allDataList.isNotEmpty) {
          // Find the most recent storage snapshot for the same device
          final targetIndex = _allDataList.indexWhere(
            (data) => data.deviceId == updateData.deviceId,
          );

          if (targetIndex != -1) {
            // Create a new storage data object with the updated key-value
            final existingData = _allDataList[targetIndex];
            final updatedStorageMap = Map<String, dynamic>.from(
              existingData.storageData,
            );

            switch (updateData.operation) {
              case 'set':
                // Set or update the key
                updatedStorageMap[updateData.key] = updateData.value;
                print(
                  '🔑 Updated key "${updateData.key}" with value: ${updateData.value}',
                );
                break;
              case 'delete':
                // Remove the key
                updatedStorageMap.remove(updateData.key);
                print('🗑️ Deleted key "${updateData.key}"');
                break;
              case 'clear':
                // Clear all data
                updatedStorageMap.clear();
                print('🧹 Cleared all storage data');
                break;
              case 'deleteAll':
                // Clear all data (same as clear)
                updatedStorageMap.clear();
                print('🧹 Deleted all storage data');
                break;
              default:
                print('❓ Unknown operation: ${updateData.operation}');
                break;
            }

            // Create new storage data with updated timestamp
            final updatedStorageData = SecureStorageData(
              storageData: updatedStorageMap,
              deviceId: existingData.deviceId,
              deviceName: existingData.deviceName,
              timestamp: updateData.timestamp,
            );

            // Replace the existing data
            _allDataList[targetIndex] = updatedStorageData;
            print('✅ Updated All Data list with specific key change');
          } else {
            print(
              '⚠️ No existing data found for device ${updateData.deviceId}, skipping All Data update',
            );
          }
        } else {
          print('ℹ️ All Data list is empty, cannot update specific key');
        }
      });

      print('✅ SecureStorage update processed successfully!');
    } catch (e, stackTrace) {
      print('❌ Error processing SecureStorage update event: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _updateSettings({required bool showNewestOnTop}) {
    setState(() {
      _showNewestOnTop = showNewestOnTop;

      // Re-sort existing data when setting changes
      _allDataList.sort((a, b) {
        if (_showNewestOnTop) {
          return b.timestamp.compareTo(a.timestamp);
        } else {
          return a.timestamp.compareTo(b.timestamp);
        }
      });

      // Re-sort existing updates when setting changes
      _updatesList.sort((a, b) {
        if (_showNewestOnTop) {
          return b.timestamp.compareTo(a.timestamp);
        } else {
          return a.timestamp.compareTo(b.timestamp);
        }
      });
    });

    StorageService.saveSettings(showNewestOnTop: showNewestOnTop);
  }

  void _clearAllData() {
    setState(() {
      _allDataList = [];
      _updatesList = [];
    });
  }

  void _clearStorageData() {
    setState(() {
      _allDataList = [];
    });
  }

  void _clearUpdates() {
    setState(() {
      _updatesList = [];
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
          // Create Key button
          TextButton(
            onPressed: _showCreateKeyDialog,
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Create Key'),
          ),
          // Fetch All button
          TextButton(
            onPressed: _forceDataRefresh,
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Fetch All'),
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
              'This tab shows all current key-value pairs in your secure storage.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _forceDataRefresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Request Data'),
            ),
          ],
        ),
      );
    }

    // Get the most recent storage snapshot
    final latestData =
        _showNewestOnTop ? _allDataList.first : _allDataList.last;
    final entries = latestData.storageData.entries.toList();

    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No storage data available.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'The secure storage appears to be empty.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with device info and key count
        Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withValues(alpha: 0.1),
                Theme.of(context).primaryColor.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storage,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${entries.length}',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entries.length == 1 ? 'Storage Key' : 'Storage Keys',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.device_hub,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          latestData.deviceName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Updated ${_formatTimestamp(latestData.timestamp)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Storage records list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isExpanded = _expandedRecords.contains(entry.key);

              return StorageRecordCard(
                storageKey: entry.key,
                value: entry.value?.toString(),
                isExpanded: isExpanded,
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedRecords.remove(entry.key);
                    } else {
                      _expandedRecords.add(entry.key);
                    }
                  });
                },
                onCopy:
                    () => _copyValueToClipboard(
                      entry.key,
                      entry.value?.toString(),
                    ),
                onEdit:
                    () =>
                        _showEditKeyDialog(entry.key, entry.value?.toString()),
                onEditKey:
                    () => _showRenameKeyDialog(
                      entry.key,
                      entry.value?.toString(),
                    ),
                onDelete: () => _showDeleteKeyDialog(entry.key),
              );
            },
          ),
        ),
      ],
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

    // Sort updates within each device group according to the setting
    for (final deviceUpdates in deviceGroups.values) {
      deviceUpdates.sort((a, b) {
        if (_showNewestOnTop) {
          return b.timestamp.compareTo(a.timestamp);
        } else {
          return a.timestamp.compareTo(b.timestamp);
        }
      });
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
            padding: const EdgeInsets.all(8.0),
            itemCount:
                deviceGroups.length > 1
                    ? (deviceGroups[_selectedDeviceId]?.length ?? 0)
                    : _updatesList.length,
            itemBuilder: (context, index) {
              final update =
                  deviceGroups.length > 1
                      ? deviceGroups[_selectedDeviceId]![index]
                      : _updatesList[index];

              // Create a unique key for each update record using timestamp and key
              final updateKey =
                  '${update.key}_${update.timestamp.millisecondsSinceEpoch}';
              final isExpanded = _expandedUpdateRecords.contains(updateKey);

              // Calculate the sequential index for this update
              final sequentialIndex = index + 1;

              return StorageRecordCard(
                storageKey: update.key,
                value: update.value,
                isExpanded: isExpanded,
                index: sequentialIndex,
                operationType: update.operation,
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedUpdateRecords.remove(updateKey);
                    } else {
                      _expandedUpdateRecords.add(updateKey);
                    }
                  });
                },
                onCopy: () => _copyValueToClipboard(update.key, update.value),
                onEdit: () => _showEditKeyDialog(update.key, update.value),
                onDelete: () => _showDeleteKeyDialog(update.key),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _requestInitialData() async {
    try {
      print('🔄 _requestInitialData called - starting data refresh...');
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

      print('📡 Calling ext.secure_storage.requestInitialData...');
      final response = await vmService.callServiceExtension(
        'ext.secure_storage.requestInitialData',
        isolateId: targetIsolateId,
        args: <String, dynamic>{},
      );

      print('✅ Initial data request sent successfully');
      print('📬 Response: ${response.json}');
      print('🔄 Waiting for data to arrive via event stream...');
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

  // Direct data refresh method that forces immediate UI update
  Future<void> _forceDataRefresh() async {
    print('🔄 Force data refresh initiated...');

    // First request fresh data
    await _requestInitialData();

    // Wait a bit for the data to arrive
    await Future.delayed(const Duration(milliseconds: 500));

    // If we still don't have updated data, try to manually trigger a refresh
    if (mounted) {
      print('🔄 Triggering setState to refresh UI...');
      setState(() {
        // This will trigger a rebuild of the widget tree
      });
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

        // Refresh data to show the empty state
        await _forceDataRefresh();
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

        // Refresh data to show the new key
        await _forceDataRefresh();
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'just now';
    }
  }

  void _copyValueToClipboard(String key, String? value) {
    if (value != null) {
      Clipboard.setData(ClipboardData(text: value));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Value copied to clipboard')),
      );
    }
  }

  void _showEditKeyDialog(String key, String? value) {
    final newKeyController = TextEditingController(text: key);
    final newValueController = TextEditingController(text: value);
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.orange),
              SizedBox(width: 8),
              Text('Edit Key'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    border: OutlineInputBorder(),
                    hintText: 'Enter the new key name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Key cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newValueController,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    border: OutlineInputBorder(),
                    hintText: 'Enter the new value',
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
                  await _editStorageKey(
                    newKeyController.text.trim(),
                    newValueController.text.trim(),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editStorageKey(String key, String value) async {
    try {
      print(
        '🔑 Starting edit key command for key: "$key" with value: "$value"',
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

      // Send edit command
      final commandData = {'operation': 'edit', 'key': key, 'value': value};

      print(
        '📡 Calling service extension: ext.secure_storage.command for edit',
      );
      final response = await vmService.callServiceExtension(
        'ext.secure_storage.command',
        isolateId: targetIsolateId,
        args: commandData,
      );

      print('✅ Edit key command sent successfully!');
      print('📬 Response: ${response.json}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Key "$key" updated successfully'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );

        // Refresh data to show the updated values
        await _forceDataRefresh();
      }
    } catch (e, stackTrace) {
      print('❌ Error sending edit key command: $e');
      print('📚 Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update key "$key": $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRenameKeyDialog(String oldKey, String? value) {
    final newKeyController = TextEditingController(text: oldKey);
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.drive_file_rename_outline, color: Colors.purple),
              SizedBox(width: 8),
              Text('Rename Key'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current key: "$oldKey"',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will delete the old key and create a new one with the same value.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newKeyController,
                  decoration: const InputDecoration(
                    labelText: 'New Key Name',
                    border: OutlineInputBorder(),
                    hintText: 'Enter the new key name',
                  ),
                  validator: (newValue) {
                    if (newValue == null || newValue.trim().isEmpty) {
                      return 'Key name cannot be empty';
                    }
                    if (newValue.trim() == oldKey) {
                      return 'New key name must be different';
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
                  await _renameStorageKey(
                    oldKey,
                    newKeyController.text.trim(),
                    value,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteKeyDialog(String key) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Confirm Deletion'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete the key "$key"?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('This action cannot be undone.'),
              const SizedBox(height: 8),
              const Text(
                'The key and its value will be permanently removed from secure storage.',
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
                await _deleteStorageKey(key);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameStorageKey(
    String oldKey,
    String newKey,
    String? value,
  ) async {
    try {
      print('🔄 Starting rename key operation: "$oldKey" -> "$newKey"');

      // Validate that we have a value to preserve
      if (value == null) {
        throw Exception('Cannot rename key: value is null');
      }

      // Step 1: Delete the old key
      print('🗑️ Step 1: Deleting old key "$oldKey"');
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

      // Delete old key
      final deleteCommandData = {'operation': 'delete', 'key': oldKey};
      print('📡 Calling service extension for delete operation');
      await vmService.callServiceExtension(
        'ext.secure_storage.command',
        isolateId: targetIsolateId,
        args: deleteCommandData,
      );
      print('✅ Old key "$oldKey" deleted successfully');

      // Step 2: Create the new key with the same value
      print('🔑 Step 2: Creating new key "$newKey" with preserved value');
      final createCommandData = {
        'operation': 'edit',
        'key': newKey,
        'value': value,
      };
      print('📡 Calling service extension for create operation');
      await vmService.callServiceExtension(
        'ext.secure_storage.command',
        isolateId: targetIsolateId,
        args: createCommandData,
      );
      print('✅ New key "$newKey" created successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Key renamed from "$oldKey" to "$newKey" successfully',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.purple,
          ),
        );

        // Refresh data to show the renamed key
        await _forceDataRefresh();
      }
    } catch (e, stackTrace) {
      print('❌ Error during rename operation: $e');
      print('📚 Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rename key "$oldKey": $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteStorageKey(String key) async {
    try {
      print('🗑️ Starting delete key command for key: "$key"');
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

      // Send delete command
      final commandData = {'operation': 'delete', 'key': key};

      print(
        '📡 Calling service extension: ext.secure_storage.command for delete',
      );
      final response = await vmService.callServiceExtension(
        'ext.secure_storage.command',
        isolateId: targetIsolateId,
        args: commandData,
      );

      print('✅ Delete key command sent successfully!');
      print('📬 Response: ${response.json}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Key "$key" deleted successfully'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh data to show the updated state
        await _forceDataRefresh();
      }
    } catch (e, stackTrace) {
      print('❌ Error sending delete key command: $e');
      print('📚 Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete key "$key": $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
