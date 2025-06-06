import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/secure_storage_data.dart';
import 'storage_card.dart';

/// A card widget to display individual Flutter Secure Storage updates
class StorageUpdateCard extends StatelessWidget {
  final SecureStorageUpdate update;

  const StorageUpdateCard({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with operation and timestamp
            Row(
              children: [
                Text(
                  update.operationIcon,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${update.operationDescription} "${update.key}"',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  _formatTimestamp(update.timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Device info
            Text(
              'Device: ${update.deviceName}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),

            if (update.value != null) ...[
              const SizedBox(height: 8),
              // Value display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF292930)
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[600]!
                            : Colors.grey[300]!,
                  ),
                ),
                child: JsonValueWidget(value: update.value),
              ),
            ],

            const SizedBox(height: 12),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (update.value != null) ...[
                  // Copy button
                  TextButton.icon(
                    onPressed: () => _copyToClipboard(context),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                  const SizedBox(width: 8),
                ],

                if (update.operation != 'delete') ...[
                  // Edit button
                  TextButton.icon(
                    onPressed: () => _showEditDialog(context),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                  const SizedBox(width: 8),
                ],

                // Delete button
                TextButton.icon(
                  onPressed: () => _showDeleteDialog(context),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    if (update.value != null) {
      try {
        await Clipboard.setData(ClipboardData(text: update.value!));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied "${update.key}" value to clipboard'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to copy to clipboard: $e'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: update.value ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit "${update.key}"'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newValue = controller.text;
                  Navigator.of(context).pop();

                  // Send command to host app
                  await _sendStorageCommand(
                    'edit',
                    update.key,
                    newValue,
                    context,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Edit command sent for "${update.key}"'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text(
              'Are you sure you want to delete the key "${update.key}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  // Send command to host app
                  await _sendStorageCommand(
                    'delete',
                    update.key,
                    null,
                    context,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Delete command sent for "${update.key}"',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _sendStorageCommand(
    String operation,
    String key,
    String? value,
    BuildContext context,
  ) async {
    print(
      '🚀 Starting storage command: $operation for key "$key" with value: $value',
    );

    try {
      print('🔌 Getting VM service...');
      final vmService = await serviceManager.onServiceAvailable;
      print('✅ VM service obtained: ${vmService.runtimeType}');

      final commandData = {'operation': operation, 'key': key, 'value': value};
      print('📦 Command data prepared: $commandData');

      // Try to check if the service extension is available first
      try {
        print('🔍 Checking available service extensions...');
        final vm = await vmService.getVM();
        if (vm.isolates?.isNotEmpty == true) {
          final isolateRef = vm.isolates!.first;
          final isolateDetails = await vmService.getIsolate(isolateRef.id!);
          print('🏷️ Available extensions: ${isolateDetails.extensionRPCs}');
        }
      } catch (e) {
        print('⚠️ Could not list extensions: $e');
      }

      // Send the command via VM service
      print('📡 Calling service extension: ext.secure_storage.command');
      final response = await vmService.callServiceExtension(
        'ext.secure_storage.command',
        args: commandData,
      );

      print('✅ Command sent successfully!');
      print('📬 Response: ${response.json}');
    } catch (e, stackTrace) {
      print('❌ Error sending storage command: $e');
      print('📚 Stack trace: $stackTrace');

      // Show error to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send $operation command: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
