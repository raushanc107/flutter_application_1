import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import '../database/database.dart';

class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  Future<String> createBackupJson() async {
    final customers = await _db.getAllCustomers();
    final transactions = await _db.getAllTransactions();
    final recurringTransactions = await _db.getAllRecurringTransactions();
    final savedCards = await _db.getAllSavedCards();

    final data = {
      'customers': customers.map((c) => c.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'recurringTransactions': recurringTransactions
          .map((r) => r.toJson())
          .toList(),
      'savedCards': savedCards.map((c) => c.toJson()).toList(),
      'version': 7, // Schema version for compatibility checking
      'exportDate': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  /// Returns bytes of the backup file
  Future<List<int>> createBackupBytes() async {
    final jsonString = await createBackupJson();
    return utf8.encode(jsonString);
  }

  /// Returns an XFile for sharing/uploading
  Future<XFile> createBackupXFile() async {
    final bytes = await createBackupBytes();
    return XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: 'application/json',
      name: createBackupFilename(),
    );
  }

  Future<void> exportData() async {
    final jsonString = await createBackupJson();

    // 3. Save/Share
    if (kIsWeb) {
      // Web: Create Blob and download
      final bytes = utf8.encode(jsonString);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = createBackupFilename();
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile: Share XFile
      final xFile = await createBackupXFile();
      await SharePlus.instance.share(
        ShareParams(files: [xFile], text: 'Khatabook Backup'),
      );
    }
  }

  String createBackupFilename() =>
      'khatabook_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';

  /// Helper to parse DateTime from either String (ISO8601) or int (milliseconds since epoch)
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.parse(value);
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    throw Exception('Invalid date format: $value');
  }

  Future<Map<String, int>> importData() async {
    // 1. Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true, // Required for Web access to bytes
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }

    String content;
    if (kIsWeb) {
      // Web: Read from bytes
      final bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('Could not read file data');
      content = utf8.decode(bytes);
    } else {
      // Mobile: Read from path using XFile to avoid dart:io dependency directly
      final path = result.files.single.path;
      if (path == null) throw Exception('Invalid file path');
      content = await XFile(path).readAsString();
    }

    return importFromJsonString(content);
  }

  Future<Map<String, int>> importFromJsonString(String content) async {
    final data = jsonDecode(content);

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid backup file format');
    }

    // 2. Parse data
    final customersData = (data['customers'] as List?) ?? [];
    final transactionsData = (data['transactions'] as List?) ?? [];

    int addedCustomers = 0;
    int addedTransactions = 0;

    // 3. Merge Customers
    final existingCustomers = await _db.getAllCustomers();
    final existingCustomerIds = existingCustomers.map((c) => c.id).toSet();

    for (final c in customersData) {
      final Map<String, dynamic> custData = c as Map<String, dynamic>;
      if (!existingCustomerIds.contains(custData['id'])) {
        await _db.insertCustomer(
          CustomersCompanion(
            id: drift.Value(custData['id'] as String),
            name: drift.Value(custData['name'] as String),
            phoneNumber: drift.Value(custData['phoneNumber'] as String),
            currentBalance: drift.Value(
              (custData['currentBalance'] as num).toDouble(),
            ),
            lastUpdated: drift.Value(_parseDateTime(custData['lastUpdated'])!),
            isExcluded: drift.Value(custData['isExcluded'] as bool? ?? false),
          ),
        );
        addedCustomers++;
      }
    }

    // 4. Merge Transactions
    final existingTransactions = await _db.getAllTransactions();
    final existingTransactionIds = existingTransactions
        .map((t) => t.id)
        .toSet();

    for (final t in transactionsData) {
      // Parse transaction data with null-safe handling for old backups
      final Map<String, dynamic> txData = t as Map<String, dynamic>;

      if (!existingTransactionIds.contains(txData['id'])) {
        await _db.insertTransaction(
          TransactionsCompanion(
            id: drift.Value(txData['id'] as String),
            customerId: drift.Value(txData['customerId'] as String),
            amount: drift.Value((txData['amount'] as num).toDouble()),
            type: drift.Value(txData['type'] as String),
            date: drift.Value(_parseDateTime(txData['date'])!),
            notes: drift.Value(txData['notes'] as String?),
            // Handle new fields with defaults for old backups
            interestRate: drift.Value(
              txData['interestRate'] != null
                  ? (txData['interestRate'] as num).toDouble()
                  : null,
            ),
            interestPeriod: drift.Value(txData['interestPeriod'] as String?),
            interestType: drift.Value(txData['interestType'] as String?),
            lastInterestCalculatedDate: drift.Value(
              _parseDateTime(txData['lastInterestCalculatedDate']),
            ),
            parentTransactionId: drift.Value(
              txData['parentTransactionId'] as String?,
            ),
            isInterestEntry: drift.Value(
              txData['isInterestEntry'] as bool? ?? false,
            ),
            isRecurringParent: drift.Value(
              txData['isRecurringParent'] as bool? ?? false,
            ),
            isPaid: drift.Value(txData['isPaid'] as bool? ?? false),
            isExcluded: drift.Value(txData['isExcluded'] as bool? ?? false),
          ),
        );
        addedTransactions++;
      }
    }

    // 5. Merge Recurring Transactions (if present in backup)
    final recurringTransactionsData =
        (data['recurringTransactions'] as List?) ?? [];
    int addedRecurringTransactions = 0;

    if (recurringTransactionsData.isNotEmpty) {
      final existingRecurring = await _db.getAllRecurringTransactions();
      final existingRecurringIds = existingRecurring.map((r) => r.id).toSet();

      for (final r in recurringTransactionsData) {
        final Map<String, dynamic> recData = r as Map<String, dynamic>;

        if (!existingRecurringIds.contains(recData['id'])) {
          await _db.insertRecurringTransaction(
            RecurringTransactionsCompanion(
              id: drift.Value(recData['id'] as String),
              customerId: drift.Value(recData['customerId'] as String),
              amount: drift.Value((recData['amount'] as num).toDouble()),
              type: drift.Value(recData['type'] as String),
              frequency: drift.Value(recData['frequency'] as String),
              startDate: drift.Value(_parseDateTime(recData['startDate'])!),
              note: drift.Value(recData['note'] as String),
              isActive: drift.Value(recData['isActive'] as bool? ?? true),
              lastGeneratedDate: drift.Value(
                _parseDateTime(recData['lastGeneratedDate']),
              ),
              linkedTransactionId: drift.Value(
                recData['linkedTransactionId'] as String?,
              ),
            ),
          );
          addedRecurringTransactions++;
        }
      }
    }

    // 6. Merge Saved Cards (absent in backups made before schema version 7)
    final savedCardsData = (data['savedCards'] as List?) ?? [];
    int addedSavedCards = 0;

    if (savedCardsData.isNotEmpty) {
      final existingCards = await _db.getAllSavedCards();
      final existingCardIds = existingCards.map((c) => c.id).toSet();
      var hasDefault = existingCards.any((c) => c.isDefault);

      for (final c in savedCardsData) {
        final Map<String, dynamic> cardData = c as Map<String, dynamic>;
        if (existingCardIds.contains(cardData['id'])) continue;

        // Never end up with two default cards after a merge.
        final wantsDefault = cardData['isDefault'] as bool? ?? false;
        final isDefault = wantsDefault && !hasDefault;
        if (isDefault) hasDefault = true;

        await _db
            .into(_db.savedCards)
            .insert(
              SavedCardsCompanion(
                id: drift.Value(cardData['id'] as String),
                name: drift.Value(cardData['name'] as String),
                issuer: drift.Value(cardData['issuer'] as String),
                cardType: drift.Value(cardData['cardType'] as String),
                network: drift.Value(cardData['network'] as String),
                cardNumber: drift.Value(cardData['cardNumber'] as String),
                expiry: drift.Value(cardData['expiry'] as String),
                holderName: drift.Value(cardData['holderName'] as String),
                colorTone: drift.Value(
                  cardData['colorTone'] as String? ?? 'indigo',
                ),
                isDefault: drift.Value(isDefault),
                createdAt: drift.Value(
                  _parseDateTime(cardData['createdAt']) ?? DateTime.now(),
                ),
              ),
            );
        addedSavedCards++;
      }
      await _db.normalizeDefaultSavedCard();
    }

    // 7. Recalculate all balances to ensure consistency
    await _db.recalculateAllBalances();

    return {
      'customers': addedCustomers,
      'transactions': addedTransactions,
      'recurringTransactions': addedRecurringTransactions,
      'savedCards': addedSavedCards,
    };
  }

  Future<Map<String, int>> restoreFromJsonString(String content) {
    return _db.transaction(() async {
      await _db.deleteAllData();
      return importFromJsonString(content);
    });
  }
}
