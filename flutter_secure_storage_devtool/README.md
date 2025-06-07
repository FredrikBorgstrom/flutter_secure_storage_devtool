# Flutter Secure Storage DevTool

A powerful DevTools extension for monitoring and managing Flutter Secure Storage in real-time during development.

| View all stored data                                              | View live updates of your data                           |
|------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| ![All Data View](https://raw.githubusercontent.com/FredrikBorgstrom/flutter_storage_devtool/b9af4d88c7dd74996bf0d71a3e75144334a0797f/flutter_secure_storage_devtool/screenshots/all_data_view.png) | ![Updates View](https://raw.githubusercontent.com/FredrikBorgstrom/flutter_storage_devtool/b9af4d88c7dd74996bf0d71a3e75144334a0797f/flutter_secure_storage_devtool/screenshots/updates_view.png) |

| Create new key dialog                                             | Delete all data dialog                         |
|------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| ![Create new key dialog](https://raw.githubusercontent.com/FredrikBorgstrom/flutter_storage_devtool/b9af4d88c7dd74996bf0d71a3e75144334a0797f/flutter_secure_storage_devtool/screenshots/create_new_key.png) | ![Updates View](https://raw.githubusercontent.com/FredrikBorgstrom/flutter_storage_devtool/b9af4d88c7dd74996bf0d71a3e75144334a0797f/flutter_secure_storage_devtool/screenshots/delete_all.png) |
## ✨ Features

### 📊 **Real-time Monitoring**
- **All Data View**: Live view of your complete secure storage state
- **Updates View**: Real-time feed of individual key-value changes
- **Automatic Listeners**: Automatically detects and monitors all storage keys
- **Multi-device Support**: Handle multiple connected devices with device selector
- **Smart Memory Management**: Efficient data handling with automatic cleanup

### 🛠️ **Interactive Management**
- **Create Keys**: Add new key-value pairs directly from DevTools
- **Edit Values**: Modify storage values with instant updates
- **Delete Keys**: Remove individual keys or clear all storage
- **Copy to Clipboard**: One-click copying of any value
- **Search & Navigation**: Easy browsing of large storage datasets

### 🎯 **Developer Experience**
- **Zero Configuration**: Works out of the box with simple setup
- **Hot Reload Friendly**: Maintains connection through hot reloads
- **Error Handling**: Graceful error handling with user feedback
- **Dark Mode Support**: Full dark/light theme support
- **Responsive UI**: Works on all screen sizes

### ⚡ **Performance Optimized**
- **Real-time Listeners**: Uses native FlutterSecureStorage listeners (no polling)
- **Incremental Updates**: Only transmits changed data, not full snapshots
- **Memory Efficient**: Automatic cleanup and data limits
- **Separate Event Streams**: Optimized data flow for different update types

## 🚀 Quick Start

### 1. Add Dependencies

```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  
dev_dependencies:
  flutter_secure_storage_devtool: ^0.1.0
```

### 2. Setup Monitoring

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _storage = const FlutterSecureStorage();
  Timer? _monitoringTimer;

  @override
  void initState() {
    super.initState();
    
    // Setup real-time monitoring (debug mode only)
    if (kDebugMode) {
      _monitoringTimer = registerSecureStorageListener(_storage);
      print('DevTools monitoring started with real-time listeners!');
    }
  }

  @override
  void dispose() {
    // Clean up monitoring when disposing
    if (kDebugMode && _monitoringTimer != null) {
      _monitoringTimer!.cancel();
      stopSecureStorageListener(_storage);
      print('DevTools monitoring stopped');
    }
    super.dispose();
  }

  // Your app code...
}
```

### 3. Open DevTools

1. Run your app with `flutter run`
2. Open Flutter DevTools (automatically opens or press 'h' in terminal)
3. Navigate to the **"Flutter Secure Storage"** tab
4. See your storage data update in real-time!

## 📚 API Reference

### Core Functions

#### `registerSecureStorageListener(storage, {recheckInterval})`
Sets up intelligent real-time monitoring with automatic command handling.

- **`storage`**: Your FlutterSecureStorage instance
- **`recheckInterval`**: How often to check for new keys (default: 5 seconds)
- **Returns**: Timer that can be cancelled for cleanup

**Features:**
- Uses native `registerListener()` for real-time change detection
- Automatically discovers and monitors new keys
- Handles all CRUD operations (create, read, update, delete)
- Registers service extensions for DevTools commands

#### `postSecureStorageToDevTools(storage)`
Manually posts a complete storage snapshot to DevTools.

#### `stopSecureStorageListener(storage)`
Cleans up all listeners and command handlers.

### Event Types

- **`SecureStorage`**: Complete storage snapshots (initial load, refresh)
- **`SecureStorageUpdate`**: Individual key changes (set, delete, clear)
- **`SecureStorageCommand`**: Bidirectional commands from DevTools (edit/delete/create)

## 🎛️ DevTools Extension Interface

### All Data Tab
- **Live Storage State**: Shows current key-value pairs from your storage
- **Interactive Table**: Copy, edit, or delete any key with one click
- **Bulk Operations**: Create new keys or delete all storage
- **Device Info**: Shows device name and last update timestamp
- **Smart Display**: Handles null values and large datasets gracefully

### Updates Tab
- **Real-time Feed**: Live stream of storage changes as they happen
- **Operation Icons**: Visual indicators (📝 edit, 🗑️ delete, 🧹 clear)
- **Timestamp Display**: Relative timestamps ("5s ago", "2m ago")
- **Action Buttons**: Copy, edit, or delete directly from update entries
- **Device Grouping**: Separate feeds for multiple connected devices

### Settings Tab
- **Show newest entries on top**: Control sort order for all data and updates
- **Extension Info**: Version information and help

## 🔄 How It Works

### Data Flow Architecture
```
Flutter App → VM Service → DevTools Extension
     ↑                            ↓
Storage Events              Commands (edit/delete)
```

### Real-time Listener System
1. **Auto-discovery**: Scans storage for existing keys on startup
2. **Native Listeners**: Registers `FlutterSecureStorage.registerListener()` for each key
3. **Change Detection**: Instantly detects any storage modifications
4. **Event Transmission**: Sends individual updates via VM service
5. **UI Updates**: DevTools UI reflects changes in real-time

### Command System
When you interact with DevTools:
1. **Command Sent**: DevTools sends command via VM service extension
2. **App Receives**: Host app receives command through service extension
3. **Storage Operation**: App performs actual storage operation (write/delete)
4. **Automatic Update**: Listeners automatically detect and broadcast changes
5. **UI Sync**: DevTools UI updates instantly without manual refresh

### Memory Management
- **Data Limits**: All Data (50 snapshots), Updates (100 entries)
- **Automatic Cleanup**: Oldest entries removed when limits exceeded
- **Device Separation**: Separate tracking for multiple devices
- **Smart Sorting**: Configurable newest/oldest first ordering

## 💡 Usage Examples

### Basic Integration
```dart
class StorageService {
  static const _storage = FlutterSecureStorage();
  
  static Future<void> init() async {
    if (kDebugMode) {
      // Start DevTools monitoring
      registerSecureStorageListener(_storage);
    }
  }
  
  static Future<String?> getValue(String key) async {
    return await _storage.read(key: key);
  }
  
  static Future<void> setValue(String key, String value) async {
    await _storage.write(key: key, value: value);
    // Listener automatically detects this change!
  }
}
```

### Manual Data Sync
```dart
// Force send current storage state to DevTools
await postSecureStorageToDevTools(_storage);

// Send specific update notification
await postSecureStorageUpdateToDevTools('username', 'john_doe', 'set');
```

### Complete Example
```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _storage = const FlutterSecureStorage();
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  final Map<String, String> _values = {};
  Timer? _monitoringTimer;

  @override
  void initState() {
    super.initState();
    _loadValues();

    // Set up DevTools monitoring with real-time listeners
    if (kDebugMode) {
      _monitoringTimer = registerSecureStorageListener(_storage);
      print('DevTools monitoring started!');
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();

    // Clean up monitoring
    if (kDebugMode && _monitoringTimer != null) {
      _monitoringTimer!.cancel();
      stopSecureStorageListener(_storage);
    }
    super.dispose();
  }

  Future<void> _loadValues() async {
    final values = await _storage.readAll();
    setState(() {
      _values.clear();
      _values.addAll(values);
    });
  }

  Future<void> _saveValue() async {
    final key = _keyController.text.trim();
    final value = _valueController.text.trim();

    if (key.isEmpty) return;

    await _storage.write(key: key, value: value);
    _keyController.clear();
    _valueController.clear();
    await _loadValues();
    
    // DevTools automatically detects this change via listeners!
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Storage Demo',
      home: Scaffold(
        appBar: AppBar(title: Text('Secure Storage DevTool Demo')),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Add key-value form
              TextField(
                controller: _keyController,
                decoration: InputDecoration(labelText: 'Key'),
              ),
              TextField(
                controller: _valueController,
                decoration: InputDecoration(labelText: 'Value'),
              ),
              ElevatedButton(
                onPressed: _saveValue,
                child: Text('Save to Secure Storage'),
              ),
              
              // Display current values
              Expanded(
                child: ListView.builder(
                  itemCount: _values.length,
                  itemBuilder: (context, index) {
                    final entry = _values.entries.elementAt(index);
                    return ListTile(
                      title: Text(entry.key),
                      subtitle: Text(entry.value),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () async {
                          await _storage.delete(key: entry.key);
                          await _loadValues();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 🔧 Troubleshooting

### Extension not receiving data?
- ✅ Ensure `kDebugMode` is true
- ✅ Check that `registerSecureStorageListener()` is called
- ✅ Verify DevTools connection (check debug console)
- ✅ Try the "Request Data" button in the All Data tab

### Commands not working?
- ✅ Commands require the listener to be active
- ✅ Check browser console for command errors in DevTools
- ✅ Ensure storage instance is accessible
- ✅ Verify VM service connection

### Dark mode styling issues?
- ✅ Update to latest version for dark mode fixes
- ✅ Check browser developer tools for CSS conflicts

### Performance concerns?
- ✅ Listeners only activate in debug mode
- ✅ Production builds have zero overhead
- ✅ Memory limits prevent unbounded growth

## 🔨 Development

### Building the Extension
```bash
cd flutter_secure_storage_devtool_extension_web
dart run devtools_extensions build_and_copy --source=. --dest=../flutter_secure_storage_devtool/extension/devtools
```

### Project Structure
```
flutter_secure_storage_devtool/
├── lib/                          # Host package (monitoring & commands)
│   └── flutter_secure_storage_devtool.dart
├── extension/devtools/           # Built DevTools extension
└── example/                      # Demo app

flutter_secure_storage_devtool_extension_web/
├── lib/src/
│   ├── widgets/                  # UI components
│   ├── models/                   # Data models  
│   ├── services/                 # Storage & utilities
│   └── constants.dart            # Configuration
└── web/                          # Extension assets
```

### Architecture Overview
- **Host Package**: Integrates with your Flutter app to monitor storage and handle commands
- **Extension Package**: Provides the DevTools UI and handles user interactions  
- **Communication**: Uses VM service events and service extensions for bidirectional communication
- **Real-time Updates**: Native storage listeners ensure instant change detection

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details. 