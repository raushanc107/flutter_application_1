import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../core/providers/language_provider.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/localization/translations.dart';
import '../../core/services/communication_service.dart';
import '../../core/services/recurring_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/models/pdf_config.dart';
import '../customers/add_customer_dialog.dart';
import 'pdf_config_dialog.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class LedgerScreen extends StatefulWidget {
  final Customer customer;

  const LedgerScreen({super.key, required this.customer});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  late Customer _currentCustomer;
  final Map<String, bool> _expandedSpecialCards = {};

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateBalance(Provider.of<AppDatabase>(context, listen: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF818CF8),
              foregroundColor: Colors.white,
              child: Text(_currentCustomer.name[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _currentCustomer.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : const Color(0xFFE5E7EB),
            height: 1,
          ),
        ),
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null // Use default dark theme bg
          : const Color(0xFFF3F4F6), // Light Gray for Light Mode
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildTransactionList(database),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomActionButtons(context, database),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummary(
    BuildContext context,
    List<Transaction> transactions,
  ) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final languageCode = Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).locale.languageCode;
    final balance = _currentCustomer.currentBalance;
    final interestTransactions = transactions
        .where((transaction) => transaction.isInterestEntry == true)
        .toList();
    final recurringTransactions = transactions
        .where(
          (transaction) =>
              !transaction.isRecurringParent &&
              transaction.parentTransactionId != null &&
              transaction.isInterestEntry != true,
        )
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
    final summaryRows = <Widget>[];
    if (interestTransactions.isNotEmpty ||
        transactions.any(
          (transaction) =>
              transaction.interestRate != null && transaction.interestRate! > 0,
        )) {
      summaryRows.add(
        _buildSummaryCategoryRow(
          key: 'interest',
          dueLabel: AppTranslations.get(languageCode, 'interest_due'),
          paidLabel: AppTranslations.get(languageCode, 'interest_paid'),
          transactions: interestTransactions,
          formatter: formatter,
          mutedColor: mutedColor,
          dueColor: const Color(0xFFF59E0B),
        ),
      );
    }
    if (transactions.any((transaction) => transaction.isRecurringParent) ||
        recurringTransactions.isNotEmpty) {
      summaryRows.add(
        _buildSummaryCategoryRow(
          key: 'recurring',
          dueLabel: AppTranslations.get(languageCode, 'recurring_due'),
          paidLabel: AppTranslations.get(languageCode, 'recurring_paid'),
          transactions: recurringTransactions,
          formatter: formatter,
          mutedColor: mutedColor,
        ),
      );
    }
    final balanceColor = balance.abs() < 0.01
        ? mutedColor
        : balance > 0
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF273449) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            balance.abs() < 0.01
                ? AppTranslations.get(languageCode, 'no_due')
                : AppTranslations.get(
                    languageCode,
                    balance > 0 ? 'ledger_get' : 'ledger_give',
                  ),
            style: TextStyle(
              color: mutedColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatter.format(balance.abs()),
            style: TextStyle(
              color: balanceColor,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          if (summaryRows.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
            const SizedBox(height: 9),
            for (var index = 0; index < summaryRows.length; index++) ...[
              if (index > 0) ...[
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
                const SizedBox(height: 8),
              ],
              summaryRows[index],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCategoryRow({
    required String key,
    required String dueLabel,
    required String paidLabel,
    required List<Transaction> transactions,
    required NumberFormat formatter,
    required Color mutedColor,
    Color? dueColor,
  }) {
    final due = transactions
        .where((transaction) => !transaction.isPaid && !transaction.isExcluded)
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final paid = transactions
        .where((transaction) => transaction.isPaid && !transaction.isExcluded)
        .fold<double>(0, (total, transaction) => total + transaction.amount);

    return Row(
      key: ValueKey('summary-row-$key'),
      children: [
        Expanded(
          child: _buildSummaryMetric(
            label: dueLabel,
            amount: formatter.format(due),
            color: due > 0 ? dueColor ?? const Color(0xFFF59E0B) : null,
            mutedColor: mutedColor,
          ),
        ),
        Container(
          width: 1,
          height: 30,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF374151)
              : const Color(0xFFE5E7EB),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryMetric(
            label: paidLabel,
            amount: formatter.format(paid),
            color: const Color(0xFF10B981),
            mutedColor: mutedColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String amount,
    required Color mutedColor,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: mutedColor)),
        const SizedBox(height: 3),
        Text(
          amount,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildReminderBar(BuildContext context) {
    if (_currentCustomer.currentBalance <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: _buildReminderButton(
              icon: FontAwesomeIcons.whatsapp,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () => _handleReminder(context, isWhatsApp: true),
            ),
          ),
          Expanded(
            child: _buildReminderButton(
              icon: Icons.message_outlined,
              label: 'SMS',
              color: const Color(0xFF3B82F6),
              onTap: () => _handleReminder(context, isWhatsApp: false),
            ),
          ),
          Expanded(
            child: _buildReminderButton(
              icon: Icons.ios_share,
              label: 'Export',
              color: const Color(0xFF8B5CF6),
              onTap: () => _handlePdfExport(
                context,
                Provider.of<AppDatabase>(context, listen: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Future<void> _handleReminder(
    BuildContext context, {
    required bool isWhatsApp,
  }) async {
    if (_currentCustomer.phoneNumber.trim().isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AddCustomerDialog(customer: _currentCustomer),
      );
      // Refresh customr data
      if (context.mounted) {
        final db = Provider.of<AppDatabase>(context, listen: false);
        final updated = await db.getCustomerById(_currentCustomer.id);
        if (updated != null) {
          setState(() {
            _currentCustomer = updated;
          });
          if (updated.phoneNumber.trim().isEmpty) return;
        } else {
          return;
        }
      } else {
        return;
      }
    }

    final balance = _currentCustomer.currentBalance;
    final absBalance = balance.abs();
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final amountStr = formatter.format(absBalance);

    final prefs = await SharedPreferences.getInstance();
    String template;

    if (balance > 0) {
      // You will get (Credit)
      template =
          prefs.getString('template_credit') ??
          "Hello {name}, your pending balance is {amount}. Please pay at your earliest convenience.";
    } else {
      // You will give (Debit - unusual to remind but valid)
      template =
          prefs.getString('template_debit') ??
          "Hello {name}, I have a credit of {amount} with you.";
    }

    final message = template
        .replaceAll('{name}', _currentCustomer.name)
        .replaceAll('{amount}', amountStr);

    try {
      bool sent;
      if (isWhatsApp) {
        sent = await CommunicationService.sendWhatsAppReminder(
          _currentCustomer.phoneNumber,
          message,
        );
      } else {
        sent = await CommunicationService.sendSmsReminder(
          _currentCustomer.phoneNumber,
          message,
        );
      }

      if (!sent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isWhatsApp ? "WhatsApp" : "SMS"} could not be launched.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handlePdfExport(
    BuildContext context,
    AppDatabase database,
  ) async {
    // Show configuration dialog
    final config = await showDialog<PdfConfig>(
      context: context,
      builder: (context) => const PdfConfigDialog(),
    );

    if (config == null || !context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get all transactions for the customer
      final transactions = await database.getTransactionsForCustomer(
        _currentCustomer.id,
      );

      // Generate PDF
      final pdfBytes = await PdfService.generateCustomerReport(
        customer: _currentCustomer,
        transactions: transactions,
        config: config,
      );

      // Save PDF to bytes
      // final pdfBytes = await pdf.save(); // Removed as service now returns bytes directly

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Generate filename
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final filename = '${_currentCustomer.name}_Report_$dateStr.pdf';

      // Share PDF using native share sheet
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _buildTransactionList(AppDatabase database) {
    return StreamBuilder<List<Transaction>>(
      stream: database.watchTransactionsForCustomer(_currentCustomer.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                'Error loading transactions: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allTransactions = snapshot.data!;

        if (allTransactions.isEmpty) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _buildBalanceSummary(context, allTransactions),
              _buildReminderBar(context),
              SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    AppTranslations.get(
                      Provider.of<LanguageProvider>(
                        context,
                      ).locale.languageCode,
                      'no_transactions',
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Grouping logic
        final List<Transaction> primaryTransactions = [];
        final Map<String, List<Transaction>> interestMap = {};

        for (final tx in allTransactions) {
          // Group if it has a parent (Interest OR Recurring Child)
          if (tx.parentTransactionId != null) {
            interestMap.putIfAbsent(tx.parentTransactionId!, () => []).add(tx);
          } else {
            primaryTransactions.add(tx);
          }
        }

        final entries =
            <
              ({
                DateTime? month,
                Transaction? transaction,
                List<Transaction>? normalTransactions,
              })
            >[];
        var normalRun = <Transaction>[];
        void addNormalRun() {
          if (normalRun.isEmpty) return;
          entries.add((
            month: null,
            transaction: null,
            normalTransactions: List<Transaction>.of(normalRun),
          ));
          normalRun = [];
        }

        DateTime? previousMonth;
        for (final transaction in primaryTransactions) {
          final month = DateTime(transaction.date.year, transaction.date.month);
          if (previousMonth == null ||
              month.year != previousMonth.year ||
              month.month != previousMonth.month) {
            addNormalRun();
            entries.add((
              month: month,
              transaction: null,
              normalTransactions: null,
            ));
            previousMonth = month;
          }

          final associatedTransactions = interestMap[transaction.id] ?? [];
          final isOrdinaryTransaction =
              !transaction.isRecurringParent &&
              !(transaction.interestRate != null &&
                  transaction.interestRate! > 0) &&
              associatedTransactions.isEmpty;

          if (isOrdinaryTransaction) {
            normalRun.add(transaction);
          } else {
            addNormalRun();
            entries.add((
              month: null,
              transaction: transaction,
              normalTransactions: null,
            ));
          }
        }
        addNormalRun();

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: entries.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildBalanceSummary(context, allTransactions);
            }
            if (index == 1) return _buildReminderBar(context);

            final entry = entries[index - 2];
            final month = entry.month;
            if (month != null) return _buildMonthSeparator(month);

            final normalTransactions = entry.normalTransactions;
            if (normalTransactions != null) {
              return _buildNormalTransactionGroup(database, normalTransactions);
            }

            final transaction = entry.transaction!;
            return _buildExpandableTransactionItem(
              context,
              database,
              transaction,
              interestMap[transaction.id] ?? [],
            );
          },
        );
      },
    );
  }

  Widget _buildNormalTransactionGroup(
    AppDatabase database,
    List<Transaction> transactions,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: ValueKey('normal-group-${transactions.first.id}'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < transactions.length; index++)
            _buildTransactionItem(
              context,
              database,
              transactions[index],
              showDivider: index < transactions.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildMonthSeparator(DateTime month) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      alignment: Alignment.centerLeft,
      child: Text(
        DateFormat('MMMM yyyy').format(month),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF9CA3AF)
              : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildExpandableTransactionItem(
    BuildContext context,
    AppDatabase database,
    Transaction tx,
    List<Transaction> associatedInterests,
  ) {
    if (tx.isRecurringParent) {
      return _buildRecurringTransactionCard(
        context,
        database,
        tx,
        associatedInterests
            .where((item) => item.isInterestEntry != true)
            .toList(),
      );
    }

    if (tx.interestRate != null && tx.interestRate! > 0) {
      return _buildInterestBearingTransactionItem(
        context,
        database,
        tx,
        associatedInterests
            .where((item) => item.isInterestEntry == true)
            .toList(),
      );
    }

    if (associatedInterests.isEmpty) {
      return _buildTransactionItem(context, database, tx);
    }

    final totalInterest = associatedInterests
        .where((item) => !item.isPaid && !item.isExcluded)
        .fold(0.0, (sum, item) => sum + item.amount);
    final isInactive = tx.isPaid || tx.isExcluded;
    final netAmount = (isInactive ? 0.0 : tx.amount) + totalInterest;

    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final isGave = tx.type == 'GAVE';
    final amountColor = isGave
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);

    bool isExpanded = false;
    return StatefulBuilder(
      builder: (context, setTileState) {
        return Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            listTileTheme: Theme.of(context).listTileTheme.copyWith(
              minLeadingWidth: 38,
              horizontalTitleGap: 11,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.only(
                left: 13,
                right: 12,
                top: 8,
                bottom: 8,
              ),
              leading: _buildBadge(tx),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatter.format(netAmount),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isInactive
                              ? const Color(0xFF9CA3AF)
                              : amountColor,
                          decoration: isInactive
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Text(
                        isGave
                            ? AppTranslations.get(
                                Provider.of<LanguageProvider>(
                                  context,
                                ).locale.languageCode,
                                'transaction_gave',
                              )
                            : AppTranslations.get(
                                Provider.of<LanguageProvider>(
                                  context,
                                ).locale.languageCode,
                                'transaction_got',
                              ),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isInactive
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      if (tx.isExcluded) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.5),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            AppTranslations.get(
                              Provider.of<LanguageProvider>(
                                context,
                              ).locale.languageCode,
                              'excluded_badge',
                            ),
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ] else if (tx.isPaid) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.5),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            AppTranslations.get(
                              Provider.of<LanguageProvider>(
                                context,
                              ).locale.languageCode,
                              'paid_label',
                            ),
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 4), // TIGHT GAP
                  AnimatedRotation(
                    turns: isExpanded ? 0 : 0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more,
                      size: 18,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
              onExpansionChanged: (expanded) {
                setTileState(() {
                  isExpanded = expanded;
                });
              },
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () =>
                    _showTransactionOptions(context, database, tx),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.notes?.isNotEmpty == true
                                ? tx.notes!
                                : AppTranslations.get(
                                    Provider.of<LanguageProvider>(
                                      context,
                                    ).locale.languageCode,
                                    'no_details',
                                  ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 11,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${DateFormat('hh:mm a').format(tx.date)}${(tx.isRecurringParent || tx.amount == 0 || (tx.interestRate != null && tx.interestRate! > 0)) ? " • ${DateFormat('dd MMM').format(tx.date)}" : ""}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                              if (!(tx.isRecurringParent || tx.amount == 0))
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "${formatter.format(tx.amount)} + ${formatter.format(totalInterest)}",
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              children: [
                if (tx.isRecurringParent)
                  _buildRecurringSummary(
                    associatedInterests
                        .where((record) => record.isInterestEntry != true)
                        .toList(),
                  ),
                ...associatedInterests.map(
                  (interest) =>
                      _buildInterestSubItem(context, database, interest),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecurringTransactionCard(
    BuildContext context,
    AppDatabase database,
    Transaction parent,
    List<Transaction> recurringRecords,
  ) {
    final languageCode = Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).locale.languageCode;

    return FutureBuilder<RecurringTransaction?>(
      future:
          (database.select(database.recurringTransactions)..where(
                (record) => record.linkedTransactionId.equals(parent.id),
              ))
              .getSingleOrNull(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red),
            title: Text(AppTranslations.get(languageCode, 'recurring_payment')),
            subtitle: Text(
              'Could not load recurring schedule: ${snapshot.error}',
            ),
          );
        }

        final schedule = snapshot.data;
        if (schedule == null) {
          return _buildTransactionItem(context, database, parent);
        }

        final formatter = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        );
        final unpaidRecords = recurringRecords
            .where((record) => !record.isPaid && !record.isExcluded)
            .toList();
        final paidRecords = recurringRecords
            .where((record) => record.isPaid && !record.isExcluded)
            .toList();
        final due = unpaidRecords.fold<double>(
          0,
          (total, record) => total + record.amount,
        );
        final paid = paidRecords.fold<double>(
          0,
          (total, record) => total + record.amount,
        );
        final nextDueDate = _getNextInterestDueDate(
          schedule.lastGeneratedDate ?? schedule.startDate,
          schedule.frequency,
        );
        final periodKey = switch (schedule.frequency) {
          'DAILY' => 'freq_daily',
          'YEARLY' => 'freq_yearly',
          _ => 'freq_monthly',
        };
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final mutedColor = isDark
            ? const Color(0xFF9CA3AF)
            : const Color(0xFF6B7280);
        final cardBorder = isDark
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0);
        final statusColor = due > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);
        var isExpanded =
            _expandedSpecialCards['recurring:${parent.id}'] ?? false;

        return StatefulBuilder(
          builder: (context, setCardState) => Container(
            margin: const EdgeInsets.fromLTRB(12, 5, 12, 9),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            key: ValueKey('recurring-card-${parent.id}'),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                InkWell(
                  onTap: () => setCardState(() {
                    isExpanded = !isExpanded;
                    _expandedSpecialCards['recurring:${parent.id}'] =
                        isExpanded;
                  }),
                  onLongPress: () =>
                      _showTransactionOptions(context, database, parent),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF302A54)
                                    : const Color(0xFFF1EEFF),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                Icons.repeat,
                                size: 20,
                                color: isDark
                                    ? const Color(0xFFC4B5FD)
                                    : const Color(0xFF6D5CE8),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    schedule.note.isNotEmpty
                                        ? schedule.note
                                        : AppTranslations.get(
                                            languageCode,
                                            'recurring_payment',
                                          ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${AppTranslations.get(languageCode, 'recurring_payment')} · '
                                    '${AppTranslations.get(languageCode, periodKey)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatter.format(schedule.amount),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: schedule.type == 'GAVE'
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInterestValue(
                                label: AppTranslations.get(languageCode, 'due'),
                                value: formatter.format(due),
                                subduedColor: mutedColor,
                                valueColor: due > 0 ? statusColor : null,
                              ),
                            ),
                            Container(width: 1, height: 29, color: cardBorder),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInterestValue(
                                label: AppTranslations.get(
                                  languageCode,
                                  'records',
                                ),
                                value: '${recurringRecords.length}',
                                subduedColor: mutedColor,
                              ),
                            ),
                            Container(width: 1, height: 29, color: cardBorder),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInterestValue(
                                label: AppTranslations.get(
                                  languageCode,
                                  'next_scheduled',
                                ),
                                value: DateFormat('dd MMM').format(nextDueDate),
                                subduedColor: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                  color: due > 0
                      ? (isDark
                            ? const Color(0xFF382E1B)
                            : const Color(0xFFFFF7E8))
                      : (isDark
                            ? const Color(0xFF172E2A)
                            : const Color(0xFFECFDF5)),
                  child: Row(
                    children: [
                      Icon(
                        schedule.isActive
                            ? (due > 0
                                  ? Icons.schedule
                                  : Icons.check_circle_outline)
                            : Icons.pause_circle_outline,
                        color: schedule.isActive ? statusColor : mutedColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          schedule.isActive
                              ? (due > 0
                                    ? '${formatter.format(due)} · '
                                          '${AppTranslations.get(languageCode, 'due')}'
                                    : '${AppTranslations.get(languageCode, 'next_scheduled')} '
                                          '${DateFormat('dd MMM').format(nextDueDate)}')
                              : AppTranslations.get(
                                  languageCode,
                                  'recurring_inactive',
                                ),
                          style: TextStyle(
                            color: schedule.isActive ? statusColor : mutedColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (recurringRecords.isNotEmpty)
                        TextButton(
                          onPressed: () => setCardState(() {
                            isExpanded = true;
                            _expandedSpecialCards['recurring:${parent.id}'] =
                                true;
                          }),
                          style: TextButton.styleFrom(
                            foregroundColor: statusColor,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 34),
                          ),
                          child: Text(
                            AppTranslations.get(languageCode, 'review'),
                          ),
                        ),
                      IconButton(
                        tooltip: isExpanded
                            ? 'Collapse details'
                            : 'View details',
                        onPressed: () => setCardState(() {
                          isExpanded = !isExpanded;
                          _expandedSpecialCards['recurring:${parent.id}'] =
                              isExpanded;
                        }),
                        visualDensity: VisualDensity.compact,
                        icon: AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.expand_more,
                            color: mutedColor,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topCenter,
                  child: isExpanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInterestSectionLabel(
                                AppTranslations.get(
                                  languageCode,
                                  'next_scheduled',
                                ),
                                mutedColor,
                              ),
                              const SizedBox(height: 7),
                              _buildNextInterestCard(
                                title:
                                    '${DateFormat('MMMM').format(nextDueDate)} '
                                    '${schedule.note}',
                                dateLabel:
                                    '${AppTranslations.get(languageCode, 'due')} '
                                    '${DateFormat('dd MMM yyyy').format(nextDueDate)} · '
                                    '${AppTranslations.get(languageCode, 'next_scheduled')}',
                                amount: schedule.amount,
                                formatter: formatter,
                                subduedColor: mutedColor,
                                key: ValueKey('recurring-next-${parent.id}'),
                              ),
                              if (unpaidRecords.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _buildInterestSectionLabel(
                                  AppTranslations.get(
                                    languageCode,
                                    'recurring_due',
                                  ),
                                  mutedColor,
                                ),
                                const SizedBox(height: 7),
                                ...unpaidRecords.map((record) {
                                  final amountColor = record.type == 'GAVE'
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981);
                                  return _buildExpansionRecordRow(
                                    key: ValueKey('recurring-due-${record.id}'),
                                    title: record.notes?.isNotEmpty == true
                                        ? record.notes!
                                        : schedule.note,
                                    dateLabel: DateFormat(
                                      'dd MMM yyyy',
                                    ).format(record.date),
                                    amount: formatter.format(record.amount),
                                    amountColor: amountColor,
                                    actionLabel: AppTranslations.get(
                                      languageCode,
                                      'mark_as_paid',
                                    ),
                                    onAction: () =>
                                        _markInterestPaid(database, record),
                                    onLongPress: () => _showTransactionOptions(
                                      context,
                                      database,
                                      record,
                                    ),
                                  );
                                }),
                              ],
                              if (paidRecords.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _buildInterestSectionLabel(
                                  '${AppTranslations.get(languageCode, 'paid_history')} · '
                                  '${formatter.format(paid)}',
                                  mutedColor,
                                ),
                                const SizedBox(height: 7),
                                ...paidRecords.map((record) {
                                  return _buildExpansionRecordRow(
                                    key: ValueKey(
                                      'recurring-paid-${record.id}',
                                    ),
                                    title: record.notes?.isNotEmpty == true
                                        ? record.notes!
                                        : schedule.note,
                                    dateLabel: DateFormat(
                                      'dd MMM yyyy',
                                    ).format(record.date),
                                    amount: formatter.format(record.amount),
                                    amountColor: mutedColor,
                                    isPaid: true,
                                    paidLabel: AppTranslations.get(
                                      languageCode,
                                      'paid_label',
                                    ),
                                    onLongPress: () => _showTransactionOptions(
                                      context,
                                      database,
                                      record,
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInterestBearingTransactionItem(
    BuildContext context,
    AppDatabase database,
    Transaction parent,
    List<Transaction> interestRecords,
  ) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final dueRecords = interestRecords
        .where((record) => !record.isPaid && !record.isExcluded)
        .toList();
    final paidRecords = interestRecords
        .where((record) => record.isPaid && !record.isExcluded)
        .toList();
    final due = dueRecords.fold<double>(
      0,
      (total, record) => total + record.amount,
    );
    final paid = paidRecords.fold<double>(
      0,
      (total, record) => total + record.amount,
    );
    final mostRecentInterestDate = interestRecords.fold<DateTime?>(
      parent.lastInterestCalculatedDate,
      (latest, record) =>
          latest == null || record.date.isAfter(latest) ? record.date : latest,
    );
    final nextDueDate = _getNextInterestDueDate(
      mostRecentInterestDate ?? parent.date,
      parent.interestPeriod,
    );
    final nextInterestAmount = parent.amount * (parent.interestRate ?? 0) / 100;
    final languageCode = Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).locale.languageCode;
    final periodKey = switch (parent.interestPeriod) {
      'YEARLY' => 'freq_yearly',
      'DAILY' => 'freq_daily',
      _ => 'freq_monthly',
    };
    final today = DateTime.now();
    final hasOverdueInterest = dueRecords.any(
      (record) => DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      ).isBefore(DateTime(today.year, today.month, today.day)),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subduedColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
    final dueColor = hasOverdueInterest
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);
    var isExpanded = _expandedSpecialCards['interest:${parent.id}'] ?? false;

    return StatefulBuilder(
      builder: (context, setTileState) {
        final statusBackground = dueRecords.isEmpty
            ? (isDark ? const Color(0xFF172E2A) : const Color(0xFFECFDF5))
            : hasOverdueInterest
            ? (isDark ? const Color(0xFF3A2022) : const Color(0xFFFEF2F2))
            : (isDark ? const Color(0xFF382E1B) : const Color(0xFFFFF7E8));
        final statusLabel = dueRecords.isEmpty
            ? AppTranslations.get(languageCode, 'interest_up_to_date')
            : hasOverdueInterest
            ? AppTranslations.get(languageCode, 'interest_overdue')
            : AppTranslations.get(languageCode, 'interest_due_today');
        final statusIcon = dueRecords.isEmpty
            ? Icons.check_circle_outline
            : hasOverdueInterest
            ? Icons.error_outline
            : Icons.schedule;
        final statusColor = dueRecords.isEmpty
            ? const Color(0xFF10B981)
            : dueColor;
        final cardBorder = isDark
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0);

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 5, 12, 9),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          key: ValueKey('interest-card-${parent.id}'),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              InkWell(
                onTap: () => setTileState(() {
                  isExpanded = !isExpanded;
                  _expandedSpecialCards['interest:${parent.id}'] = isExpanded;
                }),
                onLongPress: () =>
                    _showTransactionOptions(context, database, parent),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF302A54)
                                  : const Color(0xFFF1EEFF),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.percent,
                              size: 20,
                              color: isDark
                                  ? const Color(0xFFC4B5FD)
                                  : const Color(0xFF6D5CE8),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  parent.notes?.isNotEmpty == true
                                      ? parent.notes!
                                      : AppTranslations.get(
                                          languageCode,
                                          'no_details',
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  DateFormat('dd MMM yyyy').format(parent.date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subduedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatter.format(parent.amount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: parent.type == 'GAVE'
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                parent.type == 'GAVE'
                                    ? AppTranslations.get(
                                        languageCode,
                                        'transaction_gave',
                                      )
                                    : AppTranslations.get(
                                        languageCode,
                                        'transaction_got',
                                      ),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: subduedColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInterestValue(
                              label: AppTranslations.get(
                                languageCode,
                                'interest_rate_label',
                              ),
                              value:
                                  '${parent.interestRate}% '
                                  '${AppTranslations.get(languageCode, periodKey)}',
                              subduedColor: subduedColor,
                            ),
                          ),
                          Container(width: 1, height: 29, color: cardBorder),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInterestValue(
                              label: AppTranslations.get(
                                languageCode,
                                'interest_due',
                              ),
                              value: formatter.format(due),
                              subduedColor: subduedColor,
                              valueColor: dueRecords.isEmpty
                                  ? const Color(0xFF10B981)
                                  : dueColor,
                            ),
                          ),
                          Container(width: 1, height: 29, color: cardBorder),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInterestValue(
                              label: AppTranslations.get(
                                languageCode,
                                'next_interest',
                              ),
                              value: DateFormat('dd MMM').format(nextDueDate),
                              subduedColor: subduedColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                color: statusBackground,
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (dueRecords.length == 1)
                      TextButton(
                        onPressed: () =>
                            _markInterestPaid(database, dueRecords.single),
                        style: TextButton.styleFrom(
                          foregroundColor: dueColor,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                        ),
                        child: Text(
                          AppTranslations.get(languageCode, 'mark_as_paid'),
                        ),
                      )
                    else if (dueRecords.length > 1)
                      TextButton(
                        onPressed: () => setTileState(() {
                          isExpanded = true;
                          _expandedSpecialCards['interest:${parent.id}'] = true;
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: dueColor,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                        ),
                        child: Text(
                          AppTranslations.get(languageCode, 'review'),
                        ),
                      )
                    else
                      Text(
                        '${AppTranslations.get(languageCode, 'next_interest')} '
                        '${formatter.format(nextInterestAmount)}',
                        style: TextStyle(
                          color: subduedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    IconButton(
                      tooltip: isExpanded ? 'Collapse details' : 'View details',
                      onPressed: () => setTileState(() {
                        isExpanded = !isExpanded;
                        _expandedSpecialCards['interest:${parent.id}'] =
                            isExpanded;
                      }),
                      visualDensity: VisualDensity.compact,
                      icon: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.expand_more,
                          color: subduedColor,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInterestSectionLabel(
                              AppTranslations.get(
                                languageCode,
                                'next_scheduled',
                              ),
                              subduedColor,
                            ),
                            const SizedBox(height: 7),
                            _buildNextInterestCard(
                              title:
                                  '${DateFormat('MMMM').format(nextDueDate)} '
                                  '${AppTranslations.get(languageCode, 'interest')}',
                              dateLabel:
                                  '${AppTranslations.get(languageCode, 'due')} '
                                  '${DateFormat('dd MMM yyyy').format(nextDueDate)}',
                              amount: nextInterestAmount,
                              formatter: formatter,
                              subduedColor: subduedColor,
                              key: ValueKey('interest-next-${parent.id}'),
                            ),
                            const SizedBox(height: 14),
                            if (dueRecords.isNotEmpty) ...[
                              _buildInterestSectionLabel(
                                AppTranslations.get(
                                  languageCode,
                                  hasOverdueInterest
                                      ? 'overdue_interest'
                                      : 'due_interest_records',
                                ),
                                dueColor,
                              ),
                              const SizedBox(height: 8),
                              ...dueRecords.map(
                                (record) => _buildInterestDueRecord(
                                  context,
                                  database,
                                  record,
                                  formatter,
                                  dueColor,
                                ),
                              ),
                            ],
                            if (paidRecords.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _buildInterestSectionLabel(
                                '${AppTranslations.get(languageCode, 'paid_interest_history')} · '
                                '${formatter.format(paid)}',
                                subduedColor,
                              ),
                              const SizedBox(height: 7),
                              ...paidRecords.map((record) {
                                return _buildExpansionRecordRow(
                                  key: ValueKey('interest-paid-${record.id}'),
                                  title: record.notes?.isNotEmpty == true
                                      ? record.notes!
                                      : AppTranslations.get(
                                          languageCode,
                                          'interest',
                                        ),
                                  dateLabel: DateFormat(
                                    'dd MMM yyyy',
                                  ).format(record.date),
                                  amount: formatter.format(record.amount),
                                  amountColor: const Color(0xFF10B981),
                                  isPaid: true,
                                  paidLabel: AppTranslations.get(
                                    languageCode,
                                    'paid_label',
                                  ),
                                  onLongPress: () => _showTransactionOptions(
                                    context,
                                    database,
                                    record,
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInterestValue({
    required String label,
    required String value,
    required Color subduedColor,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: subduedColor),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  DateTime _getNextInterestDueDate(DateTime lastDate, String? period) {
    switch (period) {
      case 'DAILY':
        return lastDate.add(const Duration(days: 1));
      case 'YEARLY':
        return DateTime(
          lastDate.year + 1,
          lastDate.month,
          lastDate.day,
          lastDate.hour,
          lastDate.minute,
          lastDate.second,
        );
      case 'MONTHLY':
      default:
        return DateTime(
          lastDate.year,
          lastDate.month + 1,
          lastDate.day,
          lastDate.hour,
          lastDate.minute,
          lastDate.second,
        );
    }
  }

  Widget _buildInterestSectionLabel(String label, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInterestDueRecord(
    BuildContext context,
    AppDatabase database,
    Transaction record,
    NumberFormat formatter,
    Color accentColor,
  ) {
    final languageCode = Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).locale.languageCode;

    return _buildExpansionRecordRow(
      title: record.notes?.isNotEmpty == true
          ? record.notes!
          : AppTranslations.get(languageCode, 'interest'),
      dateLabel:
          '${AppTranslations.get(languageCode, 'due')} '
          '${DateFormat('dd MMM yyyy').format(record.date)}',
      amount: formatter.format(record.amount),
      amountColor: accentColor,
      actionLabel: AppTranslations.get(languageCode, 'mark_as_paid'),
      onAction: () => _markInterestPaid(database, record),
    );
  }

  Widget _buildNextInterestCard({
    required String title,
    required String dateLabel,
    required double amount,
    required NumberFormat formatter,
    required Color subduedColor,
    Key? key,
  }) => _buildExpansionRecordRow(
    key: key,
    title: title,
    dateLabel: dateLabel,
    amount: formatter.format(amount),
    subduedColor: subduedColor,
  );

  Widget _buildExpansionRecordRow({
    Key? key,
    required String title,
    required String dateLabel,
    required String amount,
    Color? amountColor,
    Color? subduedColor,
    bool isPaid = false,
    String? paidLabel,
    String? actionLabel,
    VoidCallback? onAction,
    VoidCallback? onLongPress,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        subduedColor ??
        (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280));

    return InkWell(
      onLongPress: onLongPress,
      child: Container(
        key: key,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: TextStyle(fontSize: 10, color: mutedColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        amountColor ?? Theme.of(context).colorScheme.onSurface,
                    decoration: isPaid ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (isPaid && paidLabel != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      paidLabel,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markInterestPaid(
    AppDatabase database,
    Transaction record,
  ) async {
    await database.updateTransaction(record.copyWith(isPaid: true));
    await _recalculateBalance(database);
  }

  Widget _buildRecurringSummary(List<Transaction> recurringRecords) {
    if (recurringRecords.isEmpty) return const SizedBox.shrink();

    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final languageCode = Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).locale.languageCode;
    final due = recurringRecords
        .where((record) => !record.isPaid && !record.isExcluded)
        .fold<double>(0, (total, record) => total + record.amount);

    return Container(
      margin: const EdgeInsets.fromLTRB(66, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1F2937)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.repeat,
            size: 18,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFA5B4FC)
                : const Color(0xFF4F46E5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.get(languageCode, 'recurring_payment'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${recurringRecords.length} '
                  '${AppTranslations.get(languageCode, 'records')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatter.format(due),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: due > 0
                  ? const Color(0xFFF59E0B)
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(Transaction tx) {
    final hasSpecialIcon =
        (tx.isInterestEntry ?? false) ||
        (tx.interestRate != null && tx.interestRate! > 0) ||
        tx.isRecurringParent ||
        tx.amount == 0;
    Color? badgeBgColor;
    Color badgeTextColor;
    Color badgeMonthColor;

    if (hasSpecialIcon) {
      if (Theme.of(context).brightness == Brightness.dark) {
        badgeBgColor = const Color(0xFF312E81);
        badgeTextColor = const Color(0xFF818CF8);
        badgeMonthColor = const Color(0xFF818CF8);
      } else {
        badgeBgColor = const Color(0xFFEDE9FE);
        badgeTextColor = const Color(0xFF4F46E5);
        badgeMonthColor = const Color(0xFF4F46E5);
      }
    } else if (Theme.of(context).brightness == Brightness.dark) {
      badgeTextColor = Colors.white;
      badgeMonthColor = const Color(0xFF9CA3AF);
    } else {
      badgeTextColor = const Color(0xFF111827);
      badgeMonthColor = const Color(0xFF6B7280);
    }

    return Container(
      key: ValueKey('transaction-badge-${tx.id}'),
      width: hasSpecialIcon ? 50 : 38,
      height: 50,
      decoration: badgeBgColor == null
          ? null
          : BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if ((tx.isInterestEntry ?? false) ||
              (tx.interestRate != null && tx.interestRate! > 0))
            Icon(Icons.percent, size: 24, color: badgeTextColor)
          else if (tx.isRecurringParent || tx.amount == 0)
            Icon(Icons.repeat, size: 24, color: badgeTextColor)
          else ...[
            Text(
              DateFormat('dd').format(tx.date),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: badgeTextColor,
              ),
            ),
            Text(
              DateFormat('MMM').format(tx.date).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: badgeMonthColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInterestSubItem(
    BuildContext context,
    AppDatabase database,
    Transaction tx,
  ) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final isGave = tx.type == 'GAVE';
    final amountColor = isGave
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);

    return InkWell(
      onLongPress: () => _showTransactionOptions(context, database, tx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(left: 66), // Align with parent content
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF374151)
                  : const Color(0xFFE5E7EB),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.notes ?? "",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(tx.date),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatter.format(tx.amount),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: (tx.isPaid || tx.isExcluded)
                        ? const Color(0xFF9CA3AF)
                        : amountColor.withValues(alpha: 0.8),
                    decoration: (tx.isPaid || tx.isExcluded)
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (tx.isExcluded)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      AppTranslations.get(
                        Provider.of<LanguageProvider>(
                          context,
                        ).locale.languageCode,
                        'excluded_badge',
                      ),
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  )
                else if (tx.isPaid)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      AppTranslations.get(
                        Provider.of<LanguageProvider>(
                          context,
                        ).locale.languageCode,
                        'paid_label',
                      ),
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),
            if (tx.isInterestEntry == true && !tx.isPaid && !tx.isExcluded)
              IconButton(
                tooltip: AppTranslations.get(
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).locale.languageCode,
                  'mark_as_paid',
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await database.updateTransaction(tx.copyWith(isPaid: true));
                  await _recalculateBalance(database);
                },
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF10B981),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    AppDatabase database,
    Transaction tx, {
    bool showDivider = true,
  }) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final isGave = tx.type == 'GAVE';
    final amountColor = isGave
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: () => _showTransactionOptions(context, database, tx),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent, // Transparent to show Gray Scaffold BG
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                    ),
                  )
                : null,
          ),
          padding: const EdgeInsets.only(
            left: 13,
            right: 12,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildBadge(tx),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.notes?.isNotEmpty == true
                                ? tx.notes!
                                : AppTranslations.get(
                                    Provider.of<LanguageProvider>(
                                      context,
                                    ).locale.languageCode,
                                    'no_details',
                                  ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: tx.notes?.isNotEmpty == true
                                  ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF111827))
                                  : const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Badges Row
                          Row(
                            children: [
                              // Time
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${DateFormat('hh:mm a').format(tx.date)}${(tx.isRecurringParent || tx.amount == 0 || (tx.interestRate != null && tx.interestRate! > 0)) ? " • ${DateFormat('dd MMM').format(tx.date)}" : ""}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                ),
                              ),

                              // Interest Info Badge for Parent Transaction
                              if (tx.interestRate != null &&
                                  tx.interestRate! > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4F46E5,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF4F46E5,
                                      ).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    "${tx.interestRate}% ${tx.interestPeriod == 'MONTHLY' ? 'Mo' : (tx.interestPeriod == 'YEARLY' ? 'Yr' : 'Day')}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ],

                              // Recurring Badge
                              if (tx.isRecurringParent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFEC4899,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFEC4899,
                                      ).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    'REPEAT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFEC4899),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Reference Badge for Interest Entry
                          if (tx.isInterestEntry ??
                              false && tx.parentTransactionId != null) ...[
                            const SizedBox(height: 4),
                            FutureBuilder<Transaction?>(
                              future: database.getTransactionById(
                                tx.parentTransactionId!,
                              ),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const SizedBox.shrink();
                                final parent = snapshot.data!;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Ref: ${parent.type == 'GAVE' ? 'Gave' : 'Got'} ₹${parent.amount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (tx.isRecurringParent || tx.amount == 0)
                        ? "Active"
                        : formatter.format(tx.amount),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: (tx.isPaid || tx.isExcluded)
                          ? const Color(0xFF9CA3AF)
                          : amountColor,
                      decoration: (tx.isPaid || tx.isExcluded)
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  Text(
                    isGave
                        ? AppTranslations.get(
                            Provider.of<LanguageProvider>(
                              context,
                            ).locale.languageCode,
                            'transaction_gave',
                          )
                        : AppTranslations.get(
                            Provider.of<LanguageProvider>(
                              context,
                            ).locale.languageCode,
                            'transaction_got',
                          ),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: (tx.isPaid || tx.isExcluded)
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  if (tx.isExcluded) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        AppTranslations.get(
                          Provider.of<LanguageProvider>(
                            context,
                          ).locale.languageCode,
                          'excluded_badge',
                        ),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ] else if (tx.isPaid) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        AppTranslations.get(
                          Provider.of<LanguageProvider>(
                            context,
                          ).locale.languageCode,
                          'paid_label',
                        ),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionOptions(
    BuildContext context,
    AppDatabase database,
    Transaction tx,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF4B5563)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF374151),
              ),
              title: Text(
                AppTranslations.get(
                  Provider.of<LanguageProvider>(context).locale.languageCode,
                  'edit_transaction',
                ),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF111827),
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showAddTransactionDialog(
                  context,
                  database,
                  tx.type,
                  existingTransaction: tx,
                );
              },
            ),
            if (!tx.isRecurringParent &&
                !(tx.interestRate != null && tx.interestRate! > 0))
              ListTile(
                leading: Icon(
                  tx.isPaid ? Icons.undo : Icons.check_circle_outline,
                  color: const Color(0xFF10B981),
                ),
                title: Text(
                  AppTranslations.get(
                    Provider.of<LanguageProvider>(context).locale.languageCode,
                    tx.isPaid ? 'mark_as_unpaid' : 'mark_as_paid',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF111827),
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await database.updateTransaction(
                    tx.copyWith(isPaid: !tx.isPaid),
                  );
                  await _recalculateBalance(database);
                },
              ),
            if (!tx.isRecurringParent)
              ListTile(
                leading: Icon(
                  tx.isExcluded
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFFF59E0B),
                ),
                title: Text(
                  AppTranslations.get(
                    Provider.of<LanguageProvider>(context).locale.languageCode,
                    tx.isExcluded
                        ? 'include_in_summary'
                        : 'exclude_from_summary',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF111827),
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await database.updateTransaction(
                    tx.copyWith(isExcluded: !tx.isExcluded),
                  );
                  await _recalculateBalance(database);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFEF4444),
              ),
              title: Text(
                AppTranslations.get(
                  Provider.of<LanguageProvider>(context).locale.languageCode,
                  'delete_transaction',
                ),
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, database, tx);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AppDatabase database,
    Transaction tx,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppTranslations.get(
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).locale.languageCode,
            'delete_transaction_title',
          ),
        ),
        content: Text(
          AppTranslations.get(
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).locale.languageCode,
            'delete_transaction_msg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppTranslations.get(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).locale.languageCode,
                'cancel',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTransaction(database, tx);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text(
              AppTranslations.get(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).locale.languageCode,
                'delete',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(AppDatabase database, Transaction tx) async {
    // deleteTransactionWithChildren returns the total balance impact (parent + interest entries)
    final totalImpact = await database.deleteTransactionWithChildren(tx);
    final newBalance = _currentCustomer.currentBalance + totalImpact;

    final updatedCustomer = _currentCustomer.copyWith(
      currentBalance: newBalance,
      lastUpdated: DateTime.now(),
    );
    await database.updateCustomer(updatedCustomer);

    setState(() {
      _currentCustomer = updatedCustomer;
    });
  }

  Widget _buildBottomActionButtons(BuildContext context, AppDatabase database) {
    final languageCode = Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).locale.languageCode;
    final paymentActionLabel = _currentCustomer.currentBalance > 0
        ? AppTranslations.get(languageCode, 'record_payment')
        : '${AppTranslations.get(languageCode, 'you_got')} ₹';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () =>
                  _showAddTransactionDialog(context, database, 'GAVE'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.remove_circle_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${AppTranslations.get(Provider.of<LanguageProvider>(context).locale.languageCode, 'you_gave')} ₹',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () =>
                  _showAddTransactionDialog(context, database, 'GOT'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    paymentActionLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(
    BuildContext context,
    AppDatabase database,
    String type, {
    Transaction? existingTransaction,
  }) async {
    // For recurring parent transactions, fetch the actual recurring config
    RecurringTransaction? recurringConfig;
    if (existingTransaction?.isRecurringParent == true) {
      recurringConfig =
          await (database.select(database.recurringTransactions)..where(
                (t) => t.linkedTransactionId.equals(existingTransaction!.id),
              ))
              .getSingleOrNull();
    }

    final formKey = GlobalKey<FormState>();
    // Use recurring config amount if this is a recurring parent, otherwise use transaction amount
    final amountController = TextEditingController(
      text:
          (recurringConfig?.amount ?? existingTransaction?.amount)
              ?.toStringAsFixed(0) ??
          '',
    );
    final notesController = TextEditingController(
      text: existingTransaction?.notes ?? '',
    );

    // Interest State
    bool isInterestEnabled = existingTransaction?.interestRate != null;
    final interestRateController = TextEditingController(
      text: existingTransaction?.interestRate?.toString() ?? '',
    );
    String interestPeriod =
        existingTransaction?.interestPeriod ?? 'MONTHLY'; // Default keys

    // Recurring State - initialize from existing config if editing a recurring parent
    bool isRecurring = existingTransaction?.isRecurringParent ?? false;
    String recurringFrequency = recurringConfig?.frequency ?? 'MONTHLY';
    bool isExcluded = existingTransaction?.isExcluded ?? false;

    // Allow editing recurring settings if this is a recurring parent
    // Or allow creating new recurring if this is a new transaction
    bool canMakeRecurring =
        existingTransaction == null || (existingTransaction.isRecurringParent);

    DateTime selectedDate = existingTransaction?.date ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Theme.of(context).cardColor,
            title: Text(
              existingTransaction == null
                  ? (type == 'GAVE'
                        ? AppTranslations.get(
                            Provider.of<LanguageProvider>(
                              context,
                            ).locale.languageCode,
                            'add_transaction_gave',
                          )
                        : AppTranslations.get(
                            Provider.of<LanguageProvider>(
                              context,
                            ).locale.languageCode,
                            'add_transaction_got',
                          ))
                  : AppTranslations.get(
                      Provider.of<LanguageProvider>(
                        context,
                      ).locale.languageCode,
                      'edit_transaction',
                    ),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF111827),
              ),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: AppTranslations.get(
                        Provider.of<LanguageProvider>(
                          context,
                        ).locale.languageCode,
                        'amount_label',
                      ),
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppTranslations.get(
                          Provider.of<LanguageProvider>(
                            context,
                          ).locale.languageCode,
                          'amount_error',
                        );
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return AppTranslations.get(
                          Provider.of<LanguageProvider>(
                            context,
                          ).locale.languageCode,
                          'amount_invalid',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Date and Time Row (Reordered to be second)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: Theme.of(context).colorScheme
                                        .copyWith(
                                          primary: const Color(0xFF4F46E5),
                                        ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: AppTranslations.get(
                                Provider.of<LanguageProvider>(
                                  context,
                                ).locale.languageCode,
                                'date_label',
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(selectedDate),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: Theme.of(context).colorScheme
                                        .copyWith(
                                          primary: const Color(0xFF4F46E5),
                                        ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedTime = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: AppTranslations.get(
                                Provider.of<LanguageProvider>(
                                  context,
                                ).locale.languageCode,
                                'time_label',
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    selectedTime.format(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.access_time, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notes Field (Third)
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: AppTranslations.get(
                        Provider.of<LanguageProvider>(
                          context,
                        ).locale.languageCode,
                        'notes_label',
                      ),
                      hintText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Interest Section (Moved to Bottom)
                  if ((existingTransaction?.isInterestEntry ?? false) != true)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: isInterestEnabled,
                                  activeColor: const Color(0xFF4F46E5),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      isInterestEnabled = val ?? false;
                                      if (isInterestEnabled) {
                                        isRecurring = false;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Include Interest", // TODO: Translate
                                style: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (isInterestEnabled) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: interestRateController,
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    decoration: InputDecoration(
                                      labelText: "Rate (%)", // TODO: Translate
                                      suffixText: '%',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Theme.of(context).cardColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 12,
                                          ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (value) {
                                      if (!isInterestEnabled) return null;
                                      if (value == null || value.isEmpty)
                                        return "Required";
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: interestPeriod,
                                    decoration: InputDecoration(
                                      labelText: "Period", // TODO: Translate
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Theme.of(context).cardColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 12,
                                          ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'MONTHLY',
                                        child: Text('Monthly'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'YEARLY',
                                        child: Text('Yearly'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'DAILY',
                                        child: Text('Daily'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(
                                          () => interestPeriod = val,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  // Recurring Section
                  if (canMakeRecurring) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: isRecurring,
                                  activeColor: const Color(0xFF4F46E5),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      isRecurring = val ?? false;
                                      // Disable interest if recurring is on (simplicity)
                                      if (isRecurring) {
                                        isInterestEnabled = false;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppTranslations.get(
                                  Provider.of<LanguageProvider>(
                                    context,
                                  ).locale.languageCode,
                                  'recurring_payment',
                                ),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (isRecurring) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: recurringFrequency,
                              decoration: InputDecoration(
                                labelText: AppTranslations.get(
                                  Provider.of<LanguageProvider>(
                                    context,
                                  ).locale.languageCode,
                                  'frequency_label',
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).cardColor,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'DAILY',
                                  child: Text(
                                    AppTranslations.get(
                                      Provider.of<LanguageProvider>(
                                        context,
                                      ).locale.languageCode,
                                      'freq_daily',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'MONTHLY',
                                  child: Text(
                                    AppTranslations.get(
                                      Provider.of<LanguageProvider>(
                                        context,
                                      ).locale.languageCode,
                                      'freq_monthly',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'YEARLY',
                                  child: Text(
                                    AppTranslations.get(
                                      Provider.of<LanguageProvider>(
                                        context,
                                      ).locale.languageCode,
                                      'freq_yearly',
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(
                                    () => recurringFrequency = val,
                                  );
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (!isRecurring) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          AppTranslations.get(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).locale.languageCode,
                            'exclude_transaction_switch',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        subtitle: Text(
                          AppTranslations.get(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).locale.languageCode,
                            'exclude_transaction_desc',
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        value: isExcluded,
                        onChanged: (val) {
                          setDialogState(() {
                            isExcluded = val;
                          });
                        },
                        activeThumbColor: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppTranslations.get(
                    Provider.of<LanguageProvider>(context).locale.languageCode,
                    'cancel',
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: type == 'GAVE'
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final amount = double.parse(amountController.text.trim());
                  final notes = notesController.text.trim();

                  // Interest parsing
                  double? interestRate;
                  if (isInterestEnabled) {
                    interestRate = double.tryParse(
                      interestRateController.text.trim(),
                    );
                  }

                  final finalDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  if (existingTransaction != null) {
                    // Check if this is a recurring parent transaction
                    if (existingTransaction.isRecurringParent) {
                      // Update the parent transaction (keep amount as 0)
                      await database.updateTransaction(
                        existingTransaction.copyWith(
                          date: finalDateTime,
                          notes: drift.Value(notes),
                        ),
                      );

                      // Update the recurring config with the new amount and frequency
                      final config =
                          await (database.select(database.recurringTransactions)
                                ..where(
                                  (t) => t.linkedTransactionId.equals(
                                    existingTransaction.id,
                                  ),
                                ))
                              .getSingleOrNull();

                      if (config != null) {
                        await database.updateRecurringTransaction(
                          config.copyWith(
                            amount: amount,
                            type: type,
                            frequency: recurringFrequency,
                            startDate: finalDateTime,
                            note: notes,
                          ),
                        );
                      }

                      // Regenerate recurring transactions
                      await RecurringService.checkAndGenerateDueTransactions(
                        database,
                      );
                      await _recalculateBalance(database);
                    } else {
                      await database.updateTransaction(
                        existingTransaction.copyWith(
                          amount: amount,
                          date: finalDateTime,
                          notes: drift.Value(notes),
                          interestRate: drift.Value(interestRate),
                          interestPeriod: drift.Value(
                            isInterestEnabled ? interestPeriod : null,
                          ),
                          // Reset calculation date if details changed
                          lastInterestCalculatedDate: const drift.Value(null),
                          isExcluded: isExcluded,
                        ),
                      );
                    }
                  } else {
                    if (isRecurring) {
                      final parentUuid = const Uuid().v4();
                      final recurringUuid = const Uuid().v4();

                      // 1. Create Parent "Setup" Transaction (Amount 0)
                      await database.insertTransaction(
                        TransactionsCompanion(
                          id: drift.Value(parentUuid),
                          customerId: drift.Value(_currentCustomer.id),
                          amount: const drift.Value(0.0), // Initial setup is 0
                          type: drift.Value(type),
                          date: drift.Value(finalDateTime),
                          notes: drift.Value(notes), // Main note
                          isRecurringParent: const drift.Value(true),
                          isExcluded: drift.Value(isExcluded),
                        ),
                      );

                      // 2. Create Recurring Config linked to Parent
                      await database.insertRecurringTransaction(
                        RecurringTransactionsCompanion(
                          id: drift.Value(recurringUuid),
                          customerId: drift.Value(_currentCustomer.id),
                          amount: drift.Value(
                            amount,
                          ), // Actual recurring amount
                          type: drift.Value(type),
                          frequency: drift.Value(recurringFrequency),
                          startDate: drift.Value(finalDateTime),
                          note: drift.Value(notes),
                          isActive: const drift.Value(true),
                          linkedTransactionId: drift.Value(parentUuid),
                        ),
                      );

                      // 3. Generate immediate transactions (will be children of parentUuid)
                      await RecurringService.checkAndGenerateDueTransactions(
                        database,
                      );
                    } else {
                      final uuid = const Uuid().v4();
                      await database.insertTransaction(
                        TransactionsCompanion(
                          id: drift.Value(uuid),
                          customerId: drift.Value(_currentCustomer.id),
                          amount: drift.Value(amount),
                          type: drift.Value(type),
                          date: drift.Value(finalDateTime),
                          notes: drift.Value(notes),
                          interestRate: drift.Value(interestRate),
                          interestPeriod: drift.Value(
                            isInterestEnabled ? interestPeriod : null,
                          ),
                          isExcluded: drift.Value(isExcluded),
                        ),
                      );
                    }
                  }

                  await _recalculateBalance(database);

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  AppTranslations.get(
                    Provider.of<LanguageProvider>(context).locale.languageCode,
                    'save',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _recalculateBalance(AppDatabase database) async {
    // Self-healing: Recalculate balance from all transactions to fix polarity issues
    final transactions = await database.getTransactionsForCustomer(
      _currentCustomer.id,
    );
    double newBalance = 0;
    for (final tx in transactions) {
      if (tx.isPaid || tx.isExcluded) continue;

      if (tx.type == 'GAVE') {
        newBalance += tx.amount;
      } else {
        newBalance -= tx.amount;
      }
    }

    // Update only if difference is significant (floating point safe check)
    if ((newBalance - _currentCustomer.currentBalance).abs() > 0.01) {
      final updatedCustomer = _currentCustomer.copyWith(
        currentBalance: newBalance,
        lastUpdated: DateTime.now(),
      );
      await database.updateCustomer(updatedCustomer);
      if (mounted) {
        setState(() {
          _currentCustomer = updatedCustomer;
        });
      }
    }
  }
}
