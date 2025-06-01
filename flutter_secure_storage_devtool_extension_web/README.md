# Flutter Secure Storage DevTool Extension Web

This is the web extension for the Flutter Secure Storage DevTool. It provides a UI for viewing and interacting with Flutter Secure Storage data in Flutter DevTools.

## Features

- View all Flutter Secure Storage values in real-time
- Filter and search through storage values
- Group values by device
- Settings for customizing the display

## Development

### Prerequisites

- Flutter SDK
- Dart SDK

### Setup

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run -d chrome` to start the extension in debug mode

### Building

To build the extension for production:

```bash
flutter build web
```

The built extension will be in the `build/web` directory.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 