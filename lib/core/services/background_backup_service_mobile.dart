import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../database/database.dart';
import '../database/native.dart' as db_connection;
import 'backup_service.dart';
import 'google_drive_auth_service.dart';
import 'google_drive_storage_service.dart';

const String backupTaskName = 'com.khatabook.backup.periodic';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == backupTaskName) {
      debugPrint("Starting background backup task");

      // 1. Check Preferences/Constraints
      final prefs = await SharedPreferences.getInstance();
      final wifiOnly = prefs.getBool('backup_wifi_only') ?? true;

      if (wifiOnly) {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (!connectivityResult.contains(ConnectivityResult.wifi)) {
          debugPrint("Background backup skipped: Not on WiFi");
          return Future.value(
            true,
          ); // Return true to indicate task finished successfully (even if skipped)
        }
      }

      try {
        // 2. Initialize Services (Fresh instances for background isolate)
        final database = AppDatabase(db_connection.connect());
        final authService = GoogleDriveAuthService();
        await authService.init();

        // 3. Check Auth Status
        final account = await authService
            .signInSilently(); // Silent sign-in for background
        if (account == null) {
          debugPrint("Background backup failed: Not signed in");
          await database.close();
          return Future.value(false); // Retry? Or fail?
        }

        final storageService = GoogleDriveStorageService(authService);
        final backupService = BackupService(database);

        // 4. Create Backup (Background is mobile only)
        final xFile = await backupService.createBackupXFile();
        final bytes = await xFile.readAsBytes();
        final stream = Stream.value(bytes);
        final length = bytes.length;
        final filename = xFile.name;

        // 5. Upload
        final timestamp = DateTime.now();
        final description = 'Auto Backup (Background) - $timestamp';
        final fileId = await storageService.uploadBackup(
          stream,
          length,
          description,
          filename,
        );

        debugPrint("Background backup successful: $fileId");
        await prefs.setString('last_backup_status', 'success');
        await prefs.setInt(
          'last_backup_time',
          timestamp.millisecondsSinceEpoch,
        );
        try {
          await storageService.cleanupOldBackups(5);
        } catch (e) {
          debugPrint("Could not clean up old backups: $e");
        }

        await database.close();
      } catch (e) {
        debugPrint("Background backup error: $e");
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_backup_status', 'error: $e');
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}
