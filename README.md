# Flutter Secure Storage DevTool

A powerful Flutter DevTools extension that provides comprehensive inspection and management capabilities for Flutter Secure Storage. Monitor, edit, create, delete, and analyze your secure storage data in real-time during development.

## ✨ Features

### 📊 **Real-time Storage Monitoring**
- Live view of all secure storage keys and values
- Automatic updates when storage data changes
- Device grouping for multi-device debugging
- Timestamp tracking for all operations

### 🔍 **Advanced Value Inspection**
- **JSON Detection & Formatting**: Automatic detection of JSON values with syntax highlighting
- **Expandable JSON View**: Click to expand JSON values with proper indentation
- **Copy Formatted JSON**: One-click copy of beautifully formatted JSON to clipboard
- **Dark Mode Support**: Optimized JSON display with black background in dark mode

### 📝 **Storage Management**
- **Create Keys**: Add new key-value pairs directly from the DevTool
- **Edit Values**: Modify existing values with validation
- **Rename Keys**: Rename storage keys while preserving their values
- **Delete Keys**: Remove individual keys or clear all storage
- **Fetch All**: Manual refresh button to get latest storage state

### 📈 **Update Tracking**
- **Indexed Updates**: Sequential numbering (#1, #2, #3...) for easy tracking
- **Operation Types**: Visual indicators for different operations:
  - 🔵 **UPDATED** - Key value was modified
  - 🔴 **DELETED** - Key was removed
  - 🟠 **CLEARED** - All storage was cleared
- **Real-time Feed**: Live stream of all storage operations as they happen

### 🎨 **Enhanced UI/UX**
- **Color-coded Actions**: Intuitive color scheme for different operations
- **Expandable Records**: Click anywhere on a record to expand JSON content
- **Responsive Design**: Optimized for various screen sizes
- **Accessibility**: Proper tooltips and keyboard navigation

## 🚀 Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_secure_storage_devtool: ^0.2.0
```

Then add the devtool listener to your app:

```dart
import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';

void main() {
  // Initialize the devtool listener
  FlutterSecureStorageDevtool.startListener();
  
  runApp(MyApp());
}
```

## 🔧 Usage

1. **Enable DevTools**: Run your Flutter app in debug mode
2. **Open DevTools**: Access through your IDE or browser
3. **Navigate to Extension**: Find "Flutter Secure Storage" in the DevTools extension tab
4. **Monitor & Manage**: View, edit, create, and delete secure storage data in real-time

### Available Actions

| Action | Description | Visual Indicator |
|--------|-------------|------------------|
| Copy | Copy value to clipboard | 📋 Blue icon |
| Edit Value | Modify the value of an existing key | ✏️ Orange icon |
| Rename Key | Change the key name while preserving value | 📝 Purple icon |
| Delete | Remove the key-value pair | 🗑️ Red icon |
| Expand JSON | View formatted JSON content | ▼ Expand arrow |

## 📱 Multi-Device Support

The DevTool automatically detects and groups storage data by device, making it easy to debug apps running on multiple devices simultaneously.

## 🎯 Use Cases

- **Debug Storage Issues**: Inspect what's actually stored vs. what you expect
- **Test Data Scenarios**: Create and modify test data on the fly  
- **Monitor Real-time Changes**: Watch how your app modifies storage during use
- **Validate JSON Data**: Ensure your stored JSON is properly formatted
- **Clean Up Storage**: Remove test data or reset storage state during development

## 🔐 Security Note

This tool is designed for **development use only**. The DevTool extension only works in debug mode and should never be included in production builds.

## 📋 Requirements

- Flutter 3.10.0 or higher
- Dart 3.0.0 or higher
- flutter_secure_storage ^9.0.0

## 🐛 Issues & Contributions

Found a bug or have a feature request? Please file an issue on our [GitHub repository](https://github.com/yourusername/flutter_secure_storage_devtool).

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
