import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../../core/services/backup_service.dart';
import '../../../core/services/google_drive_storage_service.dart';

class RestoreBackupDialog extends StatefulWidget {
  const RestoreBackupDialog({super.key});

  @override
  State<RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<RestoreBackupDialog> {
  bool _isLoading = true;
  List<drive.File> _backups = [];
  String? _error;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _fetchBackups();
  }

  Future<void> _fetchBackups() async {
    try {
      final storageService = context.read<GoogleDriveStorageService>();
      final backups = await storageService.listBackups();
      if (mounted) {
        setState(() {
          _backups = backups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreBackup(drive.File backup) async {
    if (backup.id == null) return;
    setState(() {
      _isRestoring = true;
    });

    try {
      final storageService = context.read<GoogleDriveStorageService>();
      final bytes = await storageService.downloadBackup(backup.id!);
      if (bytes == null) throw Exception("Download failed");

      final jsonString = String.fromCharCodes(bytes);

      // Call the new method we will add to BackupService
      final backupService = context.read<BackupService>();
      await backupService.importFromJsonString(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore successful! App will reload.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restore from Drive'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: _isRestoring ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isRestoring) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Restoring backup...'),
          Text('Please do not close the app.', style: TextStyle(fontSize: 12)),
        ],
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Error: $_error',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_backups.isEmpty) {
      return const Center(child: Text('No backups found on Google Drive.'));
    }

    return ListView.builder(
      itemCount: _backups.length,
      itemBuilder: (context, index) {
        final backup = _backups[index];
        final date = backup.createdTime ?? DateTime.now();
        final sizeMb = (int.parse(backup.size ?? '0') / 1024 / 1024)
            .toStringAsFixed(2);

        return ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(DateFormat.yMMMd().add_jm().format(date)),
          subtitle: Text('$sizeMb MB'),
          onTap: () => _confirmRestore(backup),
        );
      },
    );
  }

  void _confirmRestore(drive.File backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text(
          'This will replace ALL current data with the backup data. This action cannot be undone.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close confirm
              _restoreBackup(backup);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
