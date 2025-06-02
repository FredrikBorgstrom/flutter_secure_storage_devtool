import 'package:flutter/material.dart';

/// A tab for managing extension settings
class SettingsTab extends StatelessWidget {
  final bool showNewestOnTop;
  final Function({required bool showNewestOnTop}) onSettingsChanged;

  const SettingsTab({
    super.key,
    required this.showNewestOnTop,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Display Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Show newest on top setting
          SwitchListTile(
            title: const Text('Show newest entries on top'),
            subtitle: const Text(
              'When enabled, new storage data and updates will appear at the top of the list',
            ),
            value: showNewestOnTop,
            onChanged: (value) {
              onSettingsChanged(showNewestOnTop: value);
            },
          ),

          const SizedBox(height: 24),
          const Text(
            'About',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Flutter Secure Storage DevTool',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Version 0.1.0',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'This extension allows you to inspect Flutter Secure Storage values in real-time.',
          ),
        ],
      ),
    );
  }
}
