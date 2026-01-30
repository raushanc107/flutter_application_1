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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase(db_connection.connect());

  // Check for interest on startup
  try {
    final interestService = InterestService(database);
    await interestService.checkAndGenerateInterest();
  } catch (e) {
    debugPrint('Error generating interest: $e');
  }

  // Check for recurring transactions
  try {
    await RecurringService.checkAndGenerateDueTransactions(database);
  } catch (e) {
    debugPrint('Error generating recurring transactions: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>(
          create: (context) => database,
          dispose: (context, db) => db.close(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const KhatabookApp(),
    ),
  );
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
