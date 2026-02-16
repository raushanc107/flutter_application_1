import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  debugPrint("Background tasks not supported on Web");
}

const String backupTaskName = 'com.khatabook.backup.periodic';
