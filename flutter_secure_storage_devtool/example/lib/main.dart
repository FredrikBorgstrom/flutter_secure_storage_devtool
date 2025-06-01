import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_devtool/flutter_secure_storage_devtool.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Secure Storage DevTool Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Secure Storage DevTool Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _storage = const FlutterSecureStorage();
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  final Map<String, String> _values = {};
  Timer? _monitoringTimer;

  @override
  void initState() {
    super.initState();
    _loadValues();

    // Set up the DevTools listener using the improved real-time approach
    if (kDebugMode) {
      _monitoringTimer = registerSecureStorageListener(_storage);
      print('DevTools monitoring started with real-time listeners!');
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();

    // Clean up monitoring when disposing
    if (kDebugMode && _monitoringTimer != null) {
      _monitoringTimer!.cancel();
      stopSecureStorageListener(_storage);
      print('DevTools monitoring stopped');
    }

    super.dispose();
  }

  Future<void> _loadValues() async {
    final values = await _storage.readAll();
    setState(() {
      _values.clear();
      _values.addAll(values);
    });
  }

  Future<void> _saveValue() async {
    final key = _keyController.text.trim();
    final value = _valueController.text.trim();

    if (key.isEmpty) return;

    await _storage.write(key: key, value: value);
    _keyController.clear();
    _valueController.clear();

    await _loadValues();

    // Note: With the new listener-based approach, the DevTools extension
    // will automatically be notified of this change! No manual posting needed.
  }

  Future<void> _deleteValue(String key) async {
    await _storage.delete(key: key);
    await _loadValues();

    // Note: The listener will automatically detect this deletion too!
  }

  Future<void> _manualSync() async {
    // This demonstrates manual posting if you prefer more control
    if (kDebugMode) {
      await postSecureStorageToDevTools(_storage);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manually synced to DevTools!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Manually sync to DevTools',
              onPressed: _manualSync,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kDebugMode) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'DevTools Integration Active',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Real-time listeners are monitoring secure storage changes. '
                      'All changes will automatically appear in the DevTools extension!',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Add a new value:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _saveValue, child: const Text('Save')),
            const SizedBox(height: 24),
            const Text(
              'Current values:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _values.isEmpty
                  ? const Center(child: Text('No values stored'))
                  : ListView.builder(
                      itemCount: _values.length,
                      itemBuilder: (context, index) {
                        final key = _values.keys.elementAt(index);
                        final value = _values[key] ?? '';
                        return ListTile(
                          title: Text(key),
                          subtitle: Text(value),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteValue(key),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
