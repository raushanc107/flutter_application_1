enum DateRange { all, last30Days, last3Months, last6Months, lastYear, custom }

/// Which PDF to generate for a customer.
enum StatementType {
  /// Full account statement for a date range, with running balance.
  full,

  /// Short request listing only pending interest and recurring dues.
  paymentRequest,
}

class PdfConfig {
  final StatementType type;
  final DateRange dateRange;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  PdfConfig({
    this.type = StatementType.full,
    this.dateRange = DateRange.all,
    this.customStartDate,
    this.customEndDate,
  });

  /// Start of the statement period (midnight), or null for "from the beginning".
  DateTime? getStartDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (dateRange) {
      case DateRange.all:
        return null;
      case DateRange.last30Days:
        return today.subtract(const Duration(days: 30));
      case DateRange.last3Months:
        return today.subtract(const Duration(days: 90));
      case DateRange.last6Months:
        return today.subtract(const Duration(days: 180));
      case DateRange.lastYear:
        return today.subtract(const Duration(days: 365));
      case DateRange.custom:
        final s = customStartDate;
        return s == null ? null : DateTime(s.year, s.month, s.day);
    }
  }

  /// End of the statement period (inclusive, 23:59:59.999), or null for
  /// "up to now".
  DateTime? getEndDate() {
    if (dateRange == DateRange.custom && customEndDate != null) {
      final e = customEndDate!;
      return DateTime(e.year, e.month, e.day, 23, 59, 59, 999);
    }
    return null;
  }
}
