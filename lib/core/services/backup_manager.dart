import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/backup_service.dart';
import '../services/google_drive_storage_service.dart';
import '../services/google_drive_auth_service.dart';

import 'package:workmanager/workmanager.dart';
import 'background_backup_service.dart';

class BackupManager extends ChangeNotifier {
  final BackupService _backupService;
  final GoogleDriveStorageService _storageService;
  final GoogleDriveAuthService _authService;

  BackupManager(this._backupService, this._storageService, this._authService);

  // Preference Keys
  static const String _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const String _keyBackupFrequency =
      'backup_frequency'; // 'daily', 'weekly', 'monthly'
  static const String _keyWifiOnly = 'backup_wifi_only';
  static const String _keyLastBackupTime = 'last_backup_time';
  static const String _keyLastBackupStatus =
      'last_backup_status'; // 'success', 'error'

  bool _isBackingUp = false;
  bool get isBackingUp => _isBackingUp;

  // Settings
  bool _autoBackupEnabled = false;
  String _frequency = 'daily';
  bool _wifiOnly = true;
  DateTime? _lastBackupTime;
  String? _lastBackupStatus;

  bool get autoBackupEnabled => _autoBackupEnabled;
  String get frequency => _frequency;
  bool get wifiOnly => _wifiOnly;
  DateTime? get lastBackupTime => _lastBackupTime;
  String? get lastBackupStatus => _lastBackupStatus;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _autoBackupEnabled = prefs.getBool(_keyAutoBackupEnabled) ?? false;
    _frequency = prefs.getString(_keyBackupFrequency) ?? 'daily';
    _wifiOnly = prefs.getBool(_keyWifiOnly) ?? true;

    final lastTimeMillis = prefs.getInt(_keyLastBackupTime);
    if (lastTimeMillis != null) {
      _lastBackupTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMillis);
    }

    _lastBackupStatus = prefs.getString(_keyLastBackupStatus);
    await _scheduleBackgroundTask();
    notifyListeners();
  }

  Future<void> updateSettings({
    bool? enabled,
    String? frequency,
    bool? wifiOnly,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled != null) {
      _autoBackupEnabled = enabled;
      await prefs.setBool(_keyAutoBackupEnabled, enabled);
    }
    if (frequency != null) {
      _frequency = frequency;
      await prefs.setString(_keyBackupFrequency, frequency);
    }
    if (wifiOnly != null) {
      _wifiOnly = wifiOnly;
      await prefs.setBool(_keyWifiOnly, wifiOnly);
    }

    await _scheduleBackgroundTask();
    notifyListeners();
  }

  Future<void> _scheduleBackgroundTask() async {
    if (kIsWeb) return; // Background tasks not supported on Web in the same way

    if (!_autoBackupEnabled) {
      await Workmanager().cancelByUniqueName(backupTaskName);
      debugPrint("Background backup cancelled");
      return;
    }

    Duration frequencyDuration;
    switch (_frequency) {
      case 'daily':
        frequencyDuration = const Duration(days: 1);
        break;
      case 'weekly':
        frequencyDuration = const Duration(days: 7);
        break;
      case 'monthly':
        frequencyDuration = const Duration(days: 30); // Approximate
        break;
      default:
        frequencyDuration = const Duration(days: 1);
    }

    await Workmanager().registerPeriodicTask(
      backupTaskName,
      backupTaskName,
      frequency: frequencyDuration,
      constraints: Constraints(
        networkType: NetworkType
            .connected, // Basic check, detailed check inside task for WiFi
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
    debugPrint("Background backup scheduled: $_frequency");
  }

  /// Trigger a backup (Manual or Auto)
  /// Returns null if successful, or error message string
  Future<String?> performBackup({bool isAuto = false}) async {
    if (_isBackingUp) return null; // Already running

    // Connectivity Check for Auto Backup
    if (isAuto && _wifiOnly) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.wifi)) {
        debugPrint('Skipping auto-backup: Not on WiFi');
        return 'Not on WiFi';
      }
    }

    // Auth Check
    if (!_authService.isSignedIn) {
      // Try to silently sign in
      final account = await _authService
          .signIn(); // This might prompt UI, careful for background
      if (account == null) {
        return 'Not signed in to Google Drive';
      }
    }

    _isBackingUp = true;
    notifyListeners();

    try {
      Stream<List<int>> stream;
      int length;
      String filename;

      if (kIsWeb) {
        // Web: Use bytes
        final bytes = await _backupService.createBackupBytes();
        stream = Stream.value(bytes);
        length = bytes.length;
        final date = DateTime.now().toIso8601String().split('T')[0];
        filename = 'khatabook_backup_$date.json';
      } else {
        // Mobile: Use file
        final xFile = await _backupService.createBackupXFile();
        final bytes = await xFile.readAsBytes();
        stream = Stream.value(
          bytes,
        ); // Or openRead if we had a File object, but XFile readAsBytes is fine for now
        length = bytes.length;
        filename = xFile.name;
        // Optimization: For large files on mobile, we might want to use openRead from File (dart:io) but we removed it from Service.
        // XFile doesn't have openRead returning Stream<List<int>> directly compatible easily without conversion or full read.
        // For now, reading as bytes is safe for reasonable backup sizes.
      }

      // 2. Upload to Drive
      final timestamp = DateTime.now();
      final description = 'Khatabook Backup - ${_frequency} - $timestamp';
      final fileId = await _storageService.uploadBackup(
        stream,
        length,
        description,
        filename,
      );

      if (fileId != null) {
        // Success
        await _recordBackupSuccess(timestamp);

        // 3. Cleanup Old Backups (keep last 5)
        await _storageService.cleanupOldBackups(5);

        return null; // Success
      } else {
        await _recordBackupFailure('Upload failed');
        return 'Upload failed';
      }
    } catch (e) {
      final error = e.toString();
      await _recordBackupFailure(error);
      return error;
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  Future<void> _recordBackupSuccess(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    _lastBackupTime = time;
    _lastBackupStatus = 'success';
    await prefs.setInt(_keyLastBackupTime, time.millisecondsSinceEpoch);
    await prefs.setString(_keyLastBackupStatus, 'success');
  }

  Future<void> _recordBackupFailure(String error) async {
    final prefs = await SharedPreferences.getInstance();
    _lastBackupStatus = 'error: $error';
    await prefs.setString(_keyLastBackupStatus, _lastBackupStatus!);
  }
}
