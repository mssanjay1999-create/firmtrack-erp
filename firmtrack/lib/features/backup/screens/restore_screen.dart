import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});
  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  String _selectedFilePath = '';

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path!;
        _statusMessage = '';
      });
    }
  }

  Future<void> _restoreBackup() async {
    if (_selectedFilePath.isEmpty) {
      setState(() { _statusMessage = 'Please select a backup file first.'; });
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text('This will replace all current data with the backup. This cannot be undone. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _isLoading = true; _statusMessage = ''; });
    try {
      final backupFile = File(_selectedFilePath);
      if (!await backupFile.exists()) {
        setState(() { _statusMessage = 'Selected file not found.'; _isLoading = false; });
        return;
      }
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(appDir.path, 'firmtrack.db');
      await backupFile.copy(dbPath);
      setState(() { _statusMessage = 'Restore successful! Please restart the app.'; _isLoading = false; });
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore Complete'),
            content: const Text('Data restored successfully. Please close and reopen the app for changes to take effect.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)),
                child: const Text('Go to Dashboard', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() { _statusMessage = 'Restore failed: ' + e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Data'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.restore, size: 80, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Restore From Backup', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Select a backup file to restore your data. All current data will be replaced.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Select Backup File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedFilePath.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text('Selected: ' + path.basename(_selectedFilePath),
                  style: const TextStyle(color: Colors.blue)),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: (_isLoading || _selectedFilePath.isEmpty) ? null : _restoreBackup,
              icon: const Icon(Icons.restore),
              label: const Text('Restore Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 30),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('failed') ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage.contains('failed') ? Colors.red : Colors.green,
                  ),
                ),
                child: Text(_statusMessage, textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _statusMessage.contains('failed') ? Colors.red : Colors.green.shade800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
