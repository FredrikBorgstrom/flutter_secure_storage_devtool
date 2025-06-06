import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StorageRecordCard extends StatelessWidget {
  final String storageKey;
  final String? value;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback? onEditKey; // Optional callback for editing key name
  final int? index; // Optional index for updates
  final String? operationType; // Optional operation type (set, delete, clear)

  const StorageRecordCard({
    super.key,
    required this.storageKey,
    required this.value,
    required this.isExpanded,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    this.onEditKey,
    this.index,
    this.operationType,
  });

  bool _isValidJson(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    try {
      jsonDecode(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  String _formatJson(String jsonString) {
    try {
      dynamic parsedJson = jsonDecode(jsonString);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(parsedJson);
    } catch (e) {
      return jsonString;
    }
  }

  IconData _getOperationIcon(String? operation) {
    switch (operation) {
      case 'set':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'clear':
        return Icons.clear_all;
      default:
        return Icons.storage;
    }
  }

  Color _getOperationColor(String? operation) {
    switch (operation) {
      case 'set':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      case 'clear':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getOperationText(String? operation) {
    switch (operation) {
      case 'set':
        return 'UPDATED';
      case 'delete':
        return 'DELETED';
      case 'clear':
        return 'CLEARED';
      default:
        return 'UNKNOWN';
    }
  }

  Future<void> _copyFormattedJson(
    BuildContext context,
    String jsonValue,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: _formatJson(jsonValue)));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formatted JSON copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isJsonValue = _isValidJson(value);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color:
              isExpanded && isJsonValue
                  ? theme.primaryColor.withValues(alpha: 0.3)
                  : theme.dividerColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Main record row
          InkWell(
            onTap: isJsonValue ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            hoverColor:
                isJsonValue ? theme.primaryColor.withValues(alpha: 0.04) : null,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Expansion arrow
                  SizedBox(
                    width: 24,
                    child:
                        isJsonValue
                            ? Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: theme.primaryColor,
                              size: 20,
                            )
                            : const SizedBox(),
                  ),
                  const SizedBox(width: 12),

                  // Key section
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Key',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodySmall?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (operationType != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                _getOperationIcon(operationType),
                                size: 14,
                                color: _getOperationColor(operationType),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getOperationText(operationType),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getOperationColor(operationType),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          index != null ? '#$index - $storageKey' : storageKey,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Value section
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Value',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodySmall?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isJsonValue) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.data_object,
                                size: 14,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'JSON',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          value != null && value!.length > 100
                              ? '${value!.substring(0, 100)}...'
                              : value ?? 'null',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: theme.textTheme.bodySmall?.color,
                            fontStyle:
                                value == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Actions section
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          size: 18,
                          // color: theme.primaryColor,
                        ),
                        tooltip: 'Copy value',
                        onPressed: onCopy,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 18,
                          // color: Colors.orange.shade600,
                        ),
                        tooltip: 'Edit value',
                        onPressed: onEdit,
                      ),
                      if (onEditKey != null)
                        IconButton(
                          icon: Icon(
                            Icons.drive_file_rename_outline,
                            size: 18,
                            // color: Colors.purple.shade600,
                          ),
                          tooltip: 'Rename key',
                          onPressed: onEditKey,
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red.shade600,
                        ),
                        tooltip: 'Delete key',
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded JSON view
          if (isExpanded && isJsonValue && value != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(left: 52, right: 16, bottom: 16),
              decoration: BoxDecoration(
                color:
                    theme.brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.grey.shade50,
                border: Border.all(
                  color:
                      theme.brightness == Brightness.dark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with copy button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color:
                          theme.brightness == Brightness.dark
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Formatted JSON',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                theme.brightness == Brightness.dark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: 'Copy formatted JSON',
                          onPressed: () => _copyFormattedJson(context, value!),
                        ),
                      ],
                    ),
                  ),

                  // JSON content
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 300),
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _formatJson(value!),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.4,
                          color:
                              theme.brightness == Brightness.dark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
