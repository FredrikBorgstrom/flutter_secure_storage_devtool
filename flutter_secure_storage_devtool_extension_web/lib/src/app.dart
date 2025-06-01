import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'widgets/storage_display_screen.dart';

/// The main extension widget wrapper
class SecureStorageDevToolsExtension extends StatelessWidget {
  const SecureStorageDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    // The DevToolsExtension widget provides services available to extensions
    return const DevToolsExtension(
      child: StorageDisplayScreen(), // Your extension's UI
    );
  }
}
