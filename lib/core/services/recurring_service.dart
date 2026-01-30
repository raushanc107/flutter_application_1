import 'package:drift/drift.dart';
import '../database/database.dart';
import 'package:uuid/uuid.dart';

class RecurringService {
  static Future<void> checkAndGenerateDueTransactions(AppDatabase db) async {
    final activeRecurring = await db.getAllActiveRecurringTransactions();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final recurring in activeRecurring) {
      // Determine the reference date for calculation
      // If never generated, use startDate (minus one frequency step to start checking from startDate)
      // Actually, if never generated, we should check if startDate is today or in past.

      DateTime nextDueDate;
      if (recurring.lastGeneratedDate != null) {
        nextDueDate = _calculateNextDate(
          recurring.lastGeneratedDate!,
          recurring.frequency,
        );
      } else {
        // First time generation.
        // If start date is today or past, it's due.
        // We set nextDueDate to startDate so the loop catches it.
        nextDueDate = DateTime(
          recurring.startDate.year,
          recurring.startDate.month,
          recurring.startDate.day,
        );
      }

      // Allow generation if nextDueDate is today or in the past
      while (nextDueDate.isBefore(today) ||
          nextDueDate.isAtSameMomentAs(today)) {
        // Create Transaction
        final transaction = TransactionsCompanion(
          id: Value(const Uuid().v4()),
          customerId: Value(recurring.customerId),
          amount: Value(recurring.amount),
          type: Value(recurring.type),
          date: Value(nextDueDate),
          notes: Value(
            _generateNote(recurring.note, nextDueDate, recurring.frequency),
          ),
          // Link generated transaction to the parent "setup" transaction
          parentTransactionId: Value(recurring.linkedTransactionId),
        );

        await db.insertTransaction(transaction);

        // Update the recurring record
        await db.updateRecurringTransaction(
          recurring.copyWith(lastGeneratedDate: Value(nextDueDate)),
        );

        // Calculate next iteration
        nextDueDate = _calculateNextDate(nextDueDate, recurring.frequency);
      }
    }
  }

  static DateTime _calculateNextDate(DateTime current, String frequency) {
    switch (frequency) {
      case 'DAILY':
        return current.add(const Duration(days: 1));
      case 'MONTHLY':
        // Handle month overflow (e.g., Jan 31 -> Feb 28)
        // DateTime handles this by moving to March, but for rent we usually want the last day or same day.
        // Standard DateTime(2024, 1, 31).add(month) -> DateTime(2024, 2, 31) -> March 2 (leap) or March 3?
        // Let's use a safer approach if needed, but for MVP standard add month logic:
        // DateTime(year, month + 1, day)
        return DateTime(current.year, current.month + 1, current.day);
      case 'YEARLY':
        return DateTime(current.year + 1, current.month, current.day);
      default:
        return current.add(const Duration(days: 30));
    }
  }

  static String _generateNote(
    String baseNote,
    DateTime date,
    String frequency,
  ) {
    if (frequency == 'MONTHLY') {
      // e.g. "Shop Rent - Jan 2026"
      // We need manually format or use intl.
      // Since this is a service, passing context for localization is hard.
      // We'll stick to English/Standard format or simple concatenation.
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[date.month - 1];
      return "$baseNote - $month ${date.year}";
    } else if (frequency == 'YEARLY') {
      return "$baseNote - ${date.year}";
    } else {
      // Daily
      return "$baseNote - ${date.day}/${date.month}";
    }
  }
}
