# Flutter Secure Storage DevTool

A Flutter DevTools extension that displays Flutter Secure Storage values in real-time for debugging.

## Features

- View all Flutter Secure Storage values in real-time
- Filter and search through storage values
- Group values by device
- Settings for customizing the display

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_secure_storage_devtool: ^0.1.0
```

## Usage

1. Install the Flutter DevTools extension:

```bash
flutter pub global activate flutter_secure_storage_devtool
```

2. In your Flutter app, import the package and set up the listener:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';

void main() {
  final storage = FlutterSecureStorage();
  
  // Set up the listener in debug mode
  if (kDebugMode) {
    registerSecureStorageListener(storage);
  }
  
  runApp(MyApp());
}
```

3. Open Flutter DevTools and navigate to the "Flutter Secure Storage" tab.

## How it works

The package uses Flutter's DevTools extension system to send secure storage data to the DevTools UI. It periodically reads all values from the Flutter Secure Storage instance and sends them to the DevTools extension.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 