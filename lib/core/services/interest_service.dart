import '../database/database.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

class InterestService {
  final AppDatabase _db;

  InterestService(this._db);

  /// Checks all transactions and generates interest entries if due.
  Future<void> checkAndGenerateInterest() async {
    // 1. Get all transactions that have interest enabled
    // We filter in Dart because we might not have a complex WHERE clause for nullable available easily via DAO yet,
    // or we can use the select statement.
    final allTransactions = await _db.getAllTransactions();
    final interestTransactions = allTransactions
        .where((t) => t.interestRate != null && t.interestRate! > 0)
        .toList();

    for (final parentTx in interestTransactions) {
      await _processTransactionInterest(parentTx);
    }
  }

  Future<void> _processTransactionInterest(Transaction parentTx) async {
    if (parentTx.interestPeriod == null) return;

    final now = DateTime.now();
    // Start date for calculation:
    // If we have calculated before, start from there.
    // If not, start from the transaction date.
    DateTime lastCalculated =
        parentTx.lastInterestCalculatedDate ?? parentTx.date;

    // Safety check: Don't calculate for future dates
    if (lastCalculated.isAfter(now)) return;

    DateTime nextDueDate = _getNextDueDate(
      lastCalculated,
      parentTx.interestPeriod!,
    );

    bool changesMade = false;
    DateTime newLastCalculated = lastCalculated;
    DateTime currentStart =
        lastCalculated; // Track the start of the current period

    // Connect to database batch or run singly? Singly is safer for logic for now.

    // CATCH-UP LOGIC:
    // Loop while the next due date is in the past (e.g., due yesterday or months ago).
    while (nextDueDate.isBefore(now) || nextDueDate.isAtSameMomentAs(now)) {
      // Create Interest Entry
      final interestAmount = _calculateInterestAmount(parentTx);

      // Notes for the interest entry
      final periodName = _getPeriodName(parentTx.interestPeriod!);

      // Dynamic period detail based on the period start date
      // We use currentStart to represent the month/year the interest was accruing.
      String periodDetail;
      if (parentTx.interestPeriod == 'MONTHLY') {
        periodDetail = DateFormat('MMMM yyyy').format(currentStart);
      } else if (parentTx.interestPeriod == 'YEARLY') {
        periodDetail = DateFormat('yyyy').format(currentStart);
      } else {
        // DAILY
        periodDetail = DateFormat('dd MMM yyyy').format(currentStart);
      }

      final note =
          "Interest (${parentTx.interestRate}% $periodName) for $periodDetail";

      // Create the transaction
      final newTx = TransactionsCompanion(
        id: Value(_generateId()),
        customerId: Value(parentTx.customerId),
        amount: Value(interestAmount),
        type: Value(parentTx.type),
        date: Value(nextDueDate),
        notes: Value(note),
        interestRate: const Value(null),
        isInterestEntry: const Value(true),
        parentTransactionId: Value(parentTx.id),
      );

      await _db.insertTransaction(newTx);

      // Update loop variables
      currentStart = nextDueDate; // Advance the period start
      newLastCalculated = nextDueDate;
      changesMade = true;
      nextDueDate = _getNextDueDate(
        newLastCalculated,
        parentTx.interestPeriod!,
      );
    }

    if (changesMade) {
      // Update parent transaction with new last calculated date
      final updatedParent = parentTx.copyWith(
        lastInterestCalculatedDate: Value(newLastCalculated),
      );
      await _db.updateTransaction(updatedParent);
    }
  }

  double _calculateInterestAmount(Transaction tx) {
    // Simple Interest for one period
    // Formula: Principal * Rate / 100
    // Rate is per period (e.g. 1% per Month).
    // So for one month, it is Amount * 1 / 100.
    final rate = tx.interestRate ?? 0.0;
    return (tx.amount * rate) / 100.0;
  }

  DateTime _getNextDueDate(DateTime current, String period) {
    switch (period) {
      case 'DAILY':
        return current.add(const Duration(days: 1));
      case 'MONTHLY':
        // Handle month overflow? e.g. Jan 31 -> Feb 28
        // User typically expects "Same day next month"
        return DateTime(current.year, current.month + 1, current.day);
      case 'YEARLY':
        return DateTime(current.year + 1, current.month, current.day);
      default:
        return current.add(const Duration(days: 30));
    }
  }

  String _getPeriodName(String period) {
    switch (period) {
      case 'DAILY':
        return 'Daily';
      case 'MONTHLY':
        return 'Monthly';
      case 'YEARLY':
        return 'Yearly';
      default:
        return '';
    }
  }

  String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
