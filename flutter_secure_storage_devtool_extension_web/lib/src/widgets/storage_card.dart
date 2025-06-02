import 'package:flutter/material.dart';

import '../models/secure_storage_data.dart';

/// A card widget to display Flutter Secure Storage data
class StorageCard extends StatelessWidget {
  final SecureStorageData data;
  final bool hideNullValues;

  const StorageCard({
    super.key,
    required this.data,
    required this.hideNullValues,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ExpansionTile(
        title: Text(
          'Storage Data (${data.timestamp.toString()})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Device: ${data.deviceName}'),
        children: [_buildStorageDataTable()],
      ),
    );
  }

  Widget _buildStorageDataTable() {
    final entries = data.storageData.entries.toList();

    // Filter out null values if hideNullValues is true
    final filteredEntries =
        hideNullValues
            ? entries.where((entry) => entry.value != null).toList()
            : entries;

    if (filteredEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No storage data available'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Key')),
          DataColumn(label: Text('Value')),
        ],
        rows:
            filteredEntries.map((entry) {
              return DataRow(
                cells: [
                  DataCell(Text(entry.key)),
                  DataCell(
                    Text(
                      entry.value?.toString() ?? 'null',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: entry.value == null ? Colors.grey : null,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }
}
