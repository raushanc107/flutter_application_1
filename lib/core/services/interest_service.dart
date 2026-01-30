import 'package:flutter/foundation.dart';
import '../database/database.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

class InterestService {
  final AppDatabase _db;

  InterestService(this._db);

  /// Checks all transactions and generates interest entries if due.
  Future<bool> checkAndGenerateInterest() async {
    bool totalChanges = false;
    try {
      final allTransactions = await _db.getAllTransactions();
      final interestTransactions = allTransactions
          .where((t) => t.interestRate != null && (t.interestRate ?? 0.0) > 0)
          .toList();

      debugPrint(
        'InterestService: Found ${interestTransactions.length} transactions with interest settings.',
      );

      for (final parentTx in interestTransactions) {
        final changed = await _processTransactionInterest(parentTx);
        if (changed) totalChanges = true;
      }

      if (totalChanges) {
        await _db.recalculateAllBalances();
      }
    } catch (e, stack) {
      debugPrint(
        'InterestService: Critical error in checkAndGenerateInterest: $e',
      );
      debugPrint(stack.toString());
      rethrow;
    }

    return totalChanges;
  }

  Future<bool> _processTransactionInterest(Transaction parentTx) async {
    final period = parentTx.interestPeriod;
    final rate = parentTx.interestRate;

    if (period == null || rate == null) {
      debugPrint(
        'InterestService: Skipping transaction ${parentTx.id} - missing period or rate.',
      );
      return false;
    }

    final now = DateTime.now();
    DateTime lastCalculated =
        parentTx.lastInterestCalculatedDate ?? parentTx.date;

    if (lastCalculated.isAfter(now)) return false;

    // Use a safe helper for next due date
    DateTime? nextDueDate = _getNextDueDate(lastCalculated, period);
    if (nextDueDate == null) return false;

    bool changesMade = false;
    DateTime newLastCalculated = lastCalculated;
    DateTime currentStart = lastCalculated;

    debugPrint(
      'InterestService: Processing transaction ${parentTx.id} (Amount: ${parentTx.amount}, Rate: $rate%, Period: $period)',
    );

    // CATCH-UP LOGIC:
    while (nextDueDate != null &&
        (nextDueDate.isBefore(now) || nextDueDate.isAtSameMomentAs(now))) {
      final interestAmount = (parentTx.amount * rate) / 100.0;
      final periodName = _getPeriodName(period);

      String periodDetail;
      try {
        if (period == 'MONTHLY') {
          periodDetail = DateFormat('MMMM yyyy').format(currentStart);
        } else if (period == 'YEARLY') {
          periodDetail = DateFormat('yyyy').format(currentStart);
        } else {
          periodDetail = DateFormat('dd MMM yyyy').format(currentStart);
        }
      } catch (e) {
        debugPrint('InterestService: Date formatting error: $e');
        periodDetail = 'Unknown Period';
      }

      final note = "Interest ($rate% $periodName) for $periodDetail";

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
      debugPrint(
        'InterestService: Generated interest entry for ${nextDueDate.toIso8601String()}',
      );

      currentStart = nextDueDate;
      newLastCalculated = nextDueDate;
      changesMade = true;

      nextDueDate = _getNextDueDate(newLastCalculated, period);

      // Safety break to prevent infinite loops if date calculation fails or stays same
      if (nextDueDate != null && !nextDueDate.isAfter(newLastCalculated)) {
        debugPrint(
          'InterestService: WARNING: nextDueDate is not advancing! Breaking loop.',
        );
        break;
      }
    }

    if (changesMade) {
      final updatedParent = parentTx.copyWith(
        lastInterestCalculatedDate: Value(newLastCalculated),
      );
      await _db.updateTransaction(updatedParent);
    }

    return changesMade;
  }

  DateTime? _getNextDueDate(DateTime current, String period) {
    try {
      switch (period) {
        case 'DAILY':
          return current.add(const Duration(days: 1));
        case 'MONTHLY':
          return DateTime(current.year, current.month + 1, current.day);
        case 'YEARLY':
          return DateTime(current.year + 1, current.month, current.day);
        default:
          return current.add(const Duration(days: 30));
      }
    } catch (e) {
      debugPrint('InterestService: Error calculating next due date: $e');
      return null;
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
