import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/database/database.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/language_provider.dart';

// Import local platform files
import 'core/database/unsupported.dart'
    if (dart.library.html) 'core/database/web.dart'
    if (dart.library.io) 'core/database/native.dart'
    as db_connection;

import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/interest_service.dart';
import 'core/services/recurring_service.dart';
import 'core/services/google_drive_auth_service.dart';
import 'core/services/google_drive_storage_service.dart';
import 'core/services/backup_service.dart';
import 'core/services/backup_manager.dart';

import 'package:workmanager/workmanager.dart';
import 'core/services/background_backup_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase(db_connection.connect());
  final authService = GoogleDriveAuthService();
  final backupService = BackupService(database);
  final storageService = GoogleDriveStorageService(authService);
  final backupManager = BackupManager(
    backupService,
    storageService,
    authService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>(
          create: (context) => database,
          dispose: (context, db) => db.close(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),

        // Backup Providers
        ChangeNotifierProvider<GoogleDriveAuthService>.value(
          value: authService,
        ),
        Provider<GoogleDriveStorageService>.value(value: storageService),
        Provider<BackupService>.value(value: backupService),
        ChangeNotifierProvider<BackupManager>.value(value: backupManager),
      ],
      child: const KhatabookApp(),
    ),
  );

  unawaited(_initializeStartupServices(database, authService, backupManager));
}

Future<void> _initializeStartupServices(
  AppDatabase database,
  GoogleDriveAuthService authService,
  BackupManager backupManager,
) async {
  if (!kIsWeb) {
    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (e, stack) {
      debugPrint('Error initializing background backup tasks: $e');
      debugPrint(stack.toString());
    }
  }

  try {
    await InterestService(database).checkAndGenerateInterest();
  } catch (e, stack) {
    debugPrint('Error generating interest: $e');
    debugPrint(stack.toString());
  }

  try {
    await RecurringService.checkAndGenerateDueTransactions(database);
  } catch (e, stack) {
    debugPrint('Error generating recurring transactions: $e');
    debugPrint(stack.toString());
  }

  try {
    await database.recalculateAllBalances();
  } catch (e, stack) {
    debugPrint('Error recalculating customer balances: $e');
    debugPrint(stack.toString());
  }

  try {
    await authService.init();
  } catch (e, stack) {
    debugPrint('Error initializing Google Drive authentication: $e');
    debugPrint(stack.toString());
  }

  try {
    await backupManager.init();
  } catch (e, stack) {
    debugPrint('Error initializing backup manager: $e');
    debugPrint(stack.toString());
  }
}

class KhatabookApp extends StatelessWidget {
  const KhatabookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      title: 'Khatabook',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      locale: languageProvider.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('hi', ''),
        Locale(
          'en',
          'IN',
        ), // Hinglish fallback/proxy often uses en_IN + custom logic, but if 'hinglish' is used as code, we might need to add it or it defaults to standard widgets in en.
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          primary: const Color(0xFF4F46E5),
          surface: const Color(0xFFFFFFFF),
          error: const Color(0xFFEF4444),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Color(0xFF111827)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF818CF8),
          primary: const Color(0xFF818CF8),
          surface: const Color(0xFF111821),
          brightness: Brightness.dark,
          error: const Color(0xFFF87171),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
          surfaceTintColor: Color(0xFF1E293B),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
