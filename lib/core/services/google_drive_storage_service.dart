import 'package:googleapis/drive/v3.dart' as drive;
import 'package:flutter/foundation.dart';
import 'google_drive_auth_service.dart';

class GoogleDriveStorageService {
  final GoogleDriveAuthService _authService;

  GoogleDriveStorageService(this._authService);

  /// Upload a file to the App Data folder
  /// Returns the file ID on success,  /// Upload a stream to Drive
  Future<String?> uploadBackup(
    Stream<List<int>> stream,
    int length,
    String description,
    String filename,
  ) async {
    final driveApi = await _authService.getDriveApi();
    if (driveApi == null) return null;

    final media = drive.Media(stream, length);

    final driveFile = drive.File()
      ..name = filename
      ..description = description
      ..parents =
          ['appDataFolder'] // Upload to hidden App Data folder
      ..mimeType = 'application/json';

    try {
      final result = await driveApi.files.create(driveFile, uploadMedia: media);
      return result.id;
    } catch (e) {
      debugPrint('Error uploading backup: $e');
      return null;
    }
  }

  /// List all backup files in App Data folder
  Future<List<drive.File>> listBackups() async {
    final driveApi = await _authService.getDriveApi();
    if (driveApi == null) return [];

    try {
      final fileList = await driveApi.files.list(
        q: "name contains 'khatabook_backup' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, createdTime, size, description)',
        orderBy: 'createdTime desc',
      );
      return fileList.files ?? [];
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  /// Download a backup file by ID
  Future<List<int>?> downloadBackup(String fileId) async {
    final driveApi = await _authService.getDriveApi();
    if (driveApi == null) return null;

    try {
      final media =
          await driveApi.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final List<int> dataStore = [];
      await media.stream.forEach((element) {
        dataStore.addAll(element);
      });
      return dataStore;
    } catch (e) {
      debugPrint('Error downloading backup: $e');
      return null;
    }
  }

  /// Delete old backups, keeping only the [keepCount] most recent ones
  Future<void> cleanupOldBackups(int keepCount) async {
    final backups = await listBackups();
    if (backups.length <= keepCount) return;

    final backupsToDelete = backups.sublist(keepCount);
    final driveApi = await _authService.getDriveApi();
    if (driveApi == null) return;

    for (var file in backupsToDelete) {
      if (file.id != null) {
        try {
          await driveApi.files.delete(file.id!);
          debugPrint('Deleted old backup: ${file.name}');
        } catch (e) {
          debugPrint('Error deleting backup ${file.id}: $e');
        }
      }
    }
  }
}
