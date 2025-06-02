# Flutter Secure Storage DevTool

A comprehensive DevTools extension for monitoring and managing Flutter Secure Storage in debug mode.

## Features

### 📊 **Real-time Monitoring**
- **All Data View**: Complete snapshots of your secure storage
- **Updates View**: Individual key-value changes as they happen
- Automatic listener registration with real-time updates
- Multi-device support with device selector

### 🛠️ **Interactive Management**
- **Copy**: Copy any value to clipboard with one click
- **Edit**: Modify storage values directly from DevTools
- **Delete**: Remove keys with confirmation dialog
- **Search & Filter**: Hide null values, sort by newest/oldest

### 🎯 **Efficient Data Transmission**
- Individual updates only send changed data (not full storage)
- Separate event types for complete data vs. updates
- Configurable refresh intervals
- Memory-efficient with data limits (50 snapshots, 100 updates)

## Quick Start

### 1. Add to your app

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final storage = FlutterSecureStorage();
  Timer? _storageTimer;

  @override
  void initState() {
    super.initState();
    
    // Setup real-time monitoring (debug mode only)
    if (kDebugMode) {
      _storageTimer = registerSecureStorageListener(storage);
    }
  }

  @override
  void dispose() {
    _storageTimer?.cancel();
    stopSecureStorageListener(storage);
    super.dispose();
  }

  // Your app code...
}
```

### 2. Open DevTools

1. Run your app with `flutter run`
2. Open Flutter DevTools
3. Navigate to the "Flutter Secure Storage" tab
4. See your storage data in real-time!

## API Reference

### Core Functions

#### `registerSecureStorageListener(storage, {recheckInterval})`
Sets up real-time monitoring with automatic command handling.
- `storage`: Your FlutterSecureStorage instance
- `recheckInterval`: How often to check for new keys (default: 5 seconds)
- Returns: Timer that can be cancelled

#### `postSecureStorageToDevTools(storage)`
Manually posts complete storage snapshot to DevTools.

#### `stopSecureStorageListener(storage)`
Cleans up all listeners and command handlers.

### Event Types

- **`SecureStorage`**: Complete data snapshots
- **`SecureStorageUpdate`**: Individual key changes
- **`SecureStorageCommand`**: Commands from DevTools (edit/delete)

## DevTools Extension Features

### All Data Tab
- Shows complete storage snapshots
- Interactive table with copy/edit/delete buttons
- Device filtering for multi-device scenarios
- Expandable cards with timestamps

### Updates Tab  
- Real-time feed of individual changes
- Operation icons (📝 edit, 🗑️ delete, 🧹 clear)
- Relative timestamps ("5s ago", "2m ago")
- Action buttons for each update

### Settings Tab
- **Show newest on top**: Sort order preference
- **Clear on reload**: Whether to clear data when extension reloads  
- **Hide null values**: Filter out null entries

## How It Works

### Data Flow
```
Flutter App → VM Service → DevTools Extension
     ↑                            ↓
Storage Events              Commands (edit/delete)
```

### Command System
When you click edit/delete in DevTools:
1. Extension sends command via VM service
2. Host app receives command through service extension
3. App performs actual storage operation
4. App posts update event back to DevTools
5. DevTools shows the change in real-time

### Memory Management
- All Data: Maximum 50 entries (oldest removed first)
- Updates: Maximum 100 entries (configurable)
- Device-specific data grouping
- Automatic cleanup on disposal

## Examples

### Basic Setup
```dart
void setupStorageMonitoring() {
  final storage = FlutterSecureStorage();
  
  if (kDebugMode) {
    // Start monitoring
    final timer = registerSecureStorageListener(storage);
    
    // Stop monitoring later
    // timer.cancel();
    // stopSecureStorageListener(storage);
  }
}
```

### Manual Data Posting
```dart
void sendStorageUpdate() async {
  final storage = FlutterSecureStorage();
  
  if (kDebugMode) {
    // Send complete snapshot
    await postSecureStorageToDevTools(storage);
    
    // Send specific update
    await postSecureStorageUpdateToDevTools('key', 'value', 'set');
  }
}
```

## Troubleshooting

### Extension not receiving data?
- Ensure `kDebugMode` is true
- Check that `registerSecureStorageListener()` is called
- Verify DevTools connection in debug console

### Commands not working?
- Commands require the listener to be active
- Check browser console for command errors
- Ensure storage instance is available

### Clipboard not working?
- Clipboard access requires user interaction
- Some browsers may block clipboard in certain contexts
- Check for clipboard permission errors in console

## Development

### Building the Extension
```bash
cd flutter_secure_storage_devtool_extension_web
dart run devtools_extensions build_and_copy --source=. --dest=../flutter_secure_storage_devtool/extension/devtools
```

### Architecture
- **Host Package**: Handles storage operations and VM service integration
- **Extension Package**: Provides DevTools UI and command interface
- **Communication**: VM service events and service extensions 