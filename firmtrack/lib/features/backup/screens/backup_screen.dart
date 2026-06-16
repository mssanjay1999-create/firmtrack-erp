import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isLoading = false;
  String _statusMessage = '';

  Future<String> _getDbPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, 'firmtrack.db');
  }

  Future<void> _backupToDownloads() async {
    setState(() { _isLoading = true; _statusMessage = ''; });
    try {
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        setState(() { _statusMessage = 'Database file not found.'; _isLoading = false; });
        return;
      }
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) { await downloadsDir.create(recursive: true); }
      final now = DateTime.now();
      final ts = now.year.toString() + '-' + now.month.toString().padLeft(2,'0') + '-' + now.day.toString().padLeft(2,'0');
      final backupFileName = 'firmtrack_backup_' + ts + '.db';
      final backupPath = path.join(downloadsDir.path, backupFileName);
      await dbFile.copy(backupPath);
      setState(() { _statusMessage = 'Backup saved to Downloads folder.'; _isLoading = false; });
    } catch (e) {
      setState(() { _statusMessage = 'Backup failed: ' + e.toString(); _isLoading = false; });
    }
  }

  Future<void> _shareBackup() async {
    setState(() { _isLoading = true; _statusMessage = ''; });
    try {
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        setState(() { _statusMessage = 'Database file not found.'; _isLoading = false; });
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final ts = now.year.toString() + '-' + now.month.toString().padLeft(2,'0') + '-' + now.day.toString().padLeft(2,'0');
      final backupFileName = 'firmtrack_backup_' + ts + '.db';
      final tempPath = path.join(tempDir.path, backupFileName);
      await dbFile.copy(tempPath);
      await Share.shareXFiles([XFile(tempPath)], subject: 'FirmTrack Backup');
      setState(() { _statusMessage = 'Backup shared successfully.'; _isLoading = false; });
    } catch (e) {
      setState(() { _statusMessage = 'Share failed: ' + e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Data'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.backup, size: 80, color: Color(0xFF1976D2)),
            const SizedBox(height: 16),
            const Text('Backup Your Data', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Save a copy of all your FirmTrack data.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _backupToDownloads,
              icon: const Icon(Icons.download),
              label: const Text('Save to Downloads Folder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _shareBackup,
              icon: const Icon(Icons.share),
              label: const Text('Share Backup File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
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
