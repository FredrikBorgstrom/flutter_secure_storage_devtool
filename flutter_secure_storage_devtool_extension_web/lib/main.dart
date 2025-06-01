import 'package:flutter/material.dart';

import 'src/app.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false, // Disable Material 3 to avoid TabAlignment issues
      ),
      home: const SecureStorageDevToolsExtension(),
    ),
  );
}
