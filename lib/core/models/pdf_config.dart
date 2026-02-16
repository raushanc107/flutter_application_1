enum DateRange { all, last30Days, last3Months, last6Months, lastYear, custom }

class PdfConfig {
  final DateRange dateRange;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final bool includeTransactionDetails;
  final bool summaryOnly;
  final bool includeInterest;
  final bool includePaymentHistory;
  final bool includeContactInfo;
  final bool includePaidPayments;
  final String languageCode;

  PdfConfig({
    this.dateRange = DateRange.all,
    this.customStartDate,
    this.customEndDate,
    this.includeTransactionDetails = true,
    this.summaryOnly = false,
    this.includeInterest = true,
    this.includePaymentHistory = true,
    this.includeContactInfo = true,
    this.includePaidPayments = false,
    this.languageCode = 'en',
  });

  PdfConfig copyWith({
    DateRange? dateRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool? includeTransactionDetails,
    bool? summaryOnly,
    bool? includeInterest,
    bool? includePaymentHistory,
    bool? includeContactInfo,
    bool? includePaidPayments,
    String? languageCode,
  }) {
    return PdfConfig(
      dateRange: dateRange ?? this.dateRange,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      includeTransactionDetails:
          includeTransactionDetails ?? this.includeTransactionDetails,
      summaryOnly: summaryOnly ?? this.summaryOnly,
      includeInterest: includeInterest ?? this.includeInterest,
      includePaymentHistory:
          includePaymentHistory ?? this.includePaymentHistory,
      includeContactInfo: includeContactInfo ?? this.includeContactInfo,
      includePaidPayments: includePaidPayments ?? this.includePaidPayments,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  DateTime? getStartDate() {
    final now = DateTime.now();
    switch (dateRange) {
      case DateRange.all:
        return null;
      case DateRange.last30Days:
        return now.subtract(const Duration(days: 30));
      case DateRange.last3Months:
        return now.subtract(const Duration(days: 90));
      case DateRange.last6Months:
        return now.subtract(const Duration(days: 180));
      case DateRange.lastYear:
        return now.subtract(const Duration(days: 365));
      case DateRange.custom:
        return customStartDate;
    }
  }

  DateTime? getEndDate() {
    if (dateRange == DateRange.custom) {
      return customEndDate;
    }
    return null;
  }
}
