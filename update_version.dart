#!/usr/bin/env dart

import 'dart:io';

/// Simple script to update the version constant when pubspec.yaml version changes
void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart update_version.dart <version>');
    print('Example: dart update_version.dart 0.2.1');
    exit(1);
  }

  final version = args[0];

  // Update extension pubspec.yaml
  final extensionPubspec = File('pubspec.yaml');
  if (extensionPubspec.existsSync()) {
    var content = extensionPubspec.readAsStringSync();
    content = content.replaceFirst(
      RegExp(r'version: \d+\.\d+\.\d+\+\d+'),
      'version: $version+1',
    );
    extensionPubspec.writeAsStringSync(content);
    print('✅ Updated extension pubspec.yaml to version $version');
  }

  // Update version constant
  final versionFile = File('lib/src/version.dart');
  if (versionFile.existsSync()) {
    var content = versionFile.readAsStringSync();
    content = content.replaceFirst(
      RegExp(r"const String kExtensionVersion = '[^']+';"),
      "const String kExtensionVersion = '$version';",
    );
    versionFile.writeAsStringSync(content);
    print('✅ Updated version constant to $version');
  }

  // Update main package pubspec.yaml
  final mainPubspec = File('../flutter_secure_storage_devtool/pubspec.yaml');
  if (mainPubspec.existsSync()) {
    var content = mainPubspec.readAsStringSync();
    content = content.replaceFirst(
      RegExp(r'version: \d+\.\d+\.\d+'),
      'version: $version',
    );
    mainPubspec.writeAsStringSync(content);
    print('✅ Updated main package pubspec.yaml to version $version');
  }

  print('\n🎉 Version update complete! Remember to:');
  print('1. Update CHANGELOG.md');
  print('2. Run: flutter pub get');
  print(
    '3. Rebuild extension: flutter build web --debug --no-tree-shake-icons --dart-define=FLUTTER_WEB_USE_SKIA=false --source-maps',
  );
  print(
    '4. Copy build: cp -r ./build/web/. ../flutter_secure_storage_devtool/extension/devtools/build',
  );
}
