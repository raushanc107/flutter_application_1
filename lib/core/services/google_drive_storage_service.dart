import 'package:googleapis/drive/v3.dart' as drive;
import 'package:flutter/foundation.dart';
import 'google_drive_auth_service.dart';

class GoogleDriveStorageService {
  final GoogleDriveAuthService _authService;

  GoogleDriveStorageService(this._authService);

  /// Upload a backup to the App Data folder and return its Drive file ID.
  Future<String> uploadBackup(
    Stream<List<int>> stream,
    int length,
    String description,
    String filename,
  ) async {
    final driveApi = await _authService.getDriveApi();
    if (driveApi == null) {
      throw StateError('Google Drive is not authenticated');
    }

    final media = drive.Media(stream, length);

    final driveFile = drive.File()
      ..name = filename
      ..description = description
      ..parents =
          ['appDataFolder'] // Upload to hidden App Data folder
      ..mimeType = 'application/json';

    try {
      final result = await driveApi.files.create(driveFile, uploadMedia: media);
      debugPrint(
        'GoogleDrive: Uploaded backup successfully. File: ${result.name} (ID: ${result.id})',
      );
      final fileId = result.id;
      if (fileId == null) {
        throw StateError('Google Drive did not return an ID for the backup');
      }
      return fileId;
    } catch (e) {
      debugPrint('GoogleDrive Error uploading backup: $e');
      rethrow;
    }
  }

  /// List all backup files in App Data folder
  Future<List<drive.File>> listBackups() async {
    final driveApi = await _authService.getDriveApi();
    if (driveApi == null) {
      throw StateError('Google Drive is not authenticated');
    }

    try {
      final fileList = await driveApi.files.list(
        q: "trashed = false",
        spaces: 'appDataFolder',
        $fields:
            'files(id, name, createdTime, modifiedTime, size, description)',
        orderBy: 'modifiedTime desc',
      );

      final allFiles = fileList.files ?? [];
      debugPrint(
        'GoogleDrive: Found ${allFiles.length} files in appDataFolder',
      );
      for (var f in allFiles) {
        debugPrint('GoogleDrive File: ${f.name} (ID: ${f.id})');
      }

      return allFiles
          .where((f) => f.name?.contains('khatabook_backup') ?? false)
          .toList();
    } catch (e) {
      debugPrint('GoogleDrive Error listing backups: $e');
      rethrow;
    }
  }

  /// Download a backup file by ID
  Future<List<int>> downloadBackup(String fileId) async {
    final driveApi = await _authService.getDriveApi();
    if (driveApi == null) {
      throw StateError('Google Drive is not authenticated');
    }

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
      rethrow;
    }
  }

  /// Delete old backups, keeping only the [keepCount] most recent ones
  Future<void> cleanupOldBackups(int keepCount) async {
    final backups = await listBackups();
    if (backups.length <= keepCount) return;

    final backupsToDelete = backups.sublist(keepCount);
    final driveApi = await _authService.getDriveApi();
    if (driveApi == null) {
      throw StateError('Google Drive is not authenticated');
    }

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
