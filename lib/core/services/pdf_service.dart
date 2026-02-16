import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../models/pdf_config.dart';

class PdfService {
  static Future<pw.Document> generateCustomerReport({
    required Customer customer,
    required List<Transaction> transactions,
    required PdfConfig config,
  }) async {
    final pdf = pw.Document();

    // Filter transactions for calculations (always exclude paid)
    final transactionsForCalculation = _filterTransactionsForCalculation(
      transactions,
      config,
    );

    // Filter transactions for display (based on includePaidPayments config)
    final transactionsForDisplay = _filterTransactionsForDisplay(
      transactions,
      config,
    );

    // Calculate balances from unpaid transactions only
    final summary = _calculateSummary(transactionsForCalculation, config);

    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 0,
    );

    final dateFormatter = DateFormat('dd MMM yyyy');
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final widgets = <pw.Widget>[];

          // Header
          widgets.add(_buildHeader(config, now, dateFormatter));
          widgets.add(pw.SizedBox(height: 20));

          // Customer Information
          if (config.includeContactInfo) {
            widgets.add(_buildCustomerInfo(customer));
            widgets.add(pw.SizedBox(height: 20));
          }

          // Summary Section
          widgets.add(_buildSummary(summary, formatter, config));
          widgets.add(pw.SizedBox(height: 20));

          // Transaction Details
          if (config.includeTransactionDetails && !config.summaryOnly) {
            widgets.add(
              _buildTransactionTable(
                transactionsForDisplay,
                formatter,
                dateFormatter,
                config,
              ),
            );
          }

          return widgets;
        },
        footer: (context) => _buildFooter(context),
      ),
    );

    return pdf;
  }

  // Filter transactions for calculation (always exclude paid)
  static List<Transaction> _filterTransactionsForCalculation(
    List<Transaction> transactions,
    PdfConfig config,
  ) {
    var filtered = transactions.toList();

    // Filter out recurring parent transactions (they're templates with 0 amount)
    filtered = filtered.where((tx) => !tx.isRecurringParent).toList();

    // Always exclude paid transactions from calculations
    filtered = filtered.where((tx) => !tx.isPaid).toList();

    // Filter by date range
    final startDate = config.getStartDate();
    final endDate = config.getEndDate();

    if (startDate != null) {
      filtered = filtered
          .where(
            (tx) =>
                tx.date.isAfter(startDate) ||
                tx.date.isAtSameMomentAs(startDate),
          )
          .toList();
    }

    if (endDate != null) {
      filtered = filtered
          .where(
            (tx) =>
                tx.date.isBefore(endDate) || tx.date.isAtSameMomentAs(endDate),
          )
          .toList();
    }

    return filtered;
  }

  // Filter transactions for display (based on includePaidPayments config)
  static List<Transaction> _filterTransactionsForDisplay(
    List<Transaction> transactions,
    PdfConfig config,
  ) {
    var filtered = transactions.toList();

    // Filter out recurring parent transactions (they're templates with 0 amount)
    filtered = filtered.where((tx) => !tx.isRecurringParent).toList();

    // Filter by date range
    final startDate = config.getStartDate();
    final endDate = config.getEndDate();

    if (startDate != null) {
      filtered = filtered
          .where(
            (tx) =>
                tx.date.isAfter(startDate) ||
                tx.date.isAtSameMomentAs(startDate),
          )
          .toList();
    }

    if (endDate != null) {
      filtered = filtered
          .where(
            (tx) =>
                tx.date.isBefore(endDate) || tx.date.isAtSameMomentAs(endDate),
          )
          .toList();
    }

    // Filter paid transactions based on config (for display only)
    if (!config.includePaidPayments) {
      filtered = filtered.where((tx) => !tx.isPaid).toList();
    }

    // Sort by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  static Map<String, double> _calculateSummary(
    List<Transaction> transactions,
    PdfConfig config,
  ) {
    double totalCredit = 0;
    double totalDebit = 0;
    double totalInterest = 0;

    // Note: transactions passed here are already filtered to exclude paid ones
    for (final tx in transactions) {
      if (tx.type == 'GOT') {
        totalCredit += tx.amount;
      } else if (tx.type == 'GAVE') {
        totalDebit += tx.amount;
      }

      if (config.includeInterest && (tx.isInterestEntry ?? false)) {
        totalInterest += tx.amount;
      }
    }

    final currentBalance = totalCredit - totalDebit;

    return {
      'totalCredit': totalCredit,
      'totalDebit': totalDebit,
      'totalInterest': totalInterest,
      'currentBalance': currentBalance,
    };
  }

  static pw.Widget _buildHeader(
    PdfConfig config,
    DateTime now,
    DateFormat dateFormatter,
  ) {
    String periodText;
    switch (config.dateRange) {
      case DateRange.all:
        periodText = 'All Transactions';
        break;
      case DateRange.last30Days:
        periodText = 'Last 30 Days';
        break;
      case DateRange.last3Months:
        periodText = 'Last 3 Months';
        break;
      case DateRange.last6Months:
        periodText = 'Last 6 Months';
        break;
      case DateRange.lastYear:
        periodText = 'Last Year';
        break;
      case DateRange.custom:
        final start = config.customStartDate != null
            ? dateFormatter.format(config.customStartDate!)
            : 'Start';
        final end = config.customEndDate != null
            ? dateFormatter.format(config.customEndDate!)
            : 'End';
        periodText = '$start to $end';
        break;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Customer Account Statement',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo700,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Report Period: $periodText',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.Text(
              'Generated: ${dateFormatter.format(now)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Divider(thickness: 2, color: PdfColors.indigo700),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(Customer customer) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Customer Information',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo700,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(child: _buildInfoRow('Name', customer.name)),
              pw.Expanded(
                child: _buildInfoRow(
                  'Phone',
                  customer.phoneNumber.isNotEmpty
                      ? customer.phoneNumber
                      : 'N/A',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummary(
    Map<String, double> summary,
    NumberFormat formatter,
    PdfConfig config,
  ) {
    final currentBalance = summary['currentBalance']!;
    final balanceColor = currentBalance >= 0
        ? PdfColors.green700
        : PdfColors.red700;
    final balanceText = currentBalance >= 0 ? 'You will Get' : 'You will Give';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Account Summary',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                'Total Credit (Got)',
                formatter.format(summary['totalCredit']),
                PdfColors.green700,
              ),
              _buildSummaryItem(
                'Total Debit (Gave)',
                formatter.format(summary['totalDebit']),
                PdfColors.red700,
              ),
            ],
          ),
          if (config.includeInterest && summary['totalInterest']! > 0) ...[
            pw.SizedBox(height: 8),
            _buildSummaryItem(
              'Total Interest',
              formatter.format(summary['totalInterest']),
              PdfColors.purple700,
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                balanceText,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.Text(
                formatter.format(currentBalance.abs()),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: balanceColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(
    String label,
    String value,
    PdfColor color,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTransactionTable(
    List<Transaction> transactions,
    NumberFormat formatter,
    DateFormat dateFormatter,
    PdfConfig config,
  ) {
    if (transactions.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'No transactions found for the selected period',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Transaction Details',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo700,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableHeader('Date'),
                _buildTableHeader('Type'),
                _buildTableHeader('Description'),
                _buildTableHeader('Amount'),
                _buildTableHeader('Status'),
              ],
            ),
            // Data rows
            ...transactions.map(
              (tx) => _buildTransactionRow(tx, formatter, dateFormatter),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.TableRow _buildTransactionRow(
    Transaction tx,
    NumberFormat formatter,
    DateFormat dateFormatter,
  ) {
    final isCredit = tx.type == 'GOT';
    final amountColor = isCredit ? PdfColors.green700 : PdfColors.red700;

    String typeText = tx.type;
    if (tx.isInterestEntry ?? false) {
      typeText = 'Interest';
    } else if (tx.isRecurringParent) {
      typeText = 'Recurring';
    }

    return pw.TableRow(
      children: [
        _buildTableCell(dateFormatter.format(tx.date)),
        _buildTableCell(typeText),
        _buildTableCell(
          tx.notes?.isNotEmpty == true ? tx.notes! : 'No details',
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            formatter.format(tx.amount),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: amountColor,
            ),
          ),
        ),
        _buildTableCell(tx.isPaid ? 'PAID' : '-'),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 16),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }
}
