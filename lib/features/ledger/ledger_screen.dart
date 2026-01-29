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
import '../customers/add_customer_dialog.dart';

class LedgerScreen extends StatefulWidget {
  final Customer customer;

  const LedgerScreen({super.key, required this.customer});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  late Customer _currentCustomer;

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
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentCustomer.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentCustomer.currentBalance.abs() < 0.01
                        ? AppTranslations.get(
                            Provider.of<LanguageProvider>(
                              context,
                            ).locale.languageCode,
                            'no_due',
                          )
                        : '${_currentCustomer.currentBalance > 0 ? AppTranslations.get(Provider.of<LanguageProvider>(context).locale.languageCode, 'ledger_get') : AppTranslations.get(Provider.of<LanguageProvider>(context).locale.languageCode, 'ledger_give')} ${formatter.format(_currentCustomer.currentBalance.abs())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _currentCustomer.currentBalance.abs() < 0.01
                          ? const Color(0xFF6B7280) // Neutral Gray
                          : (_currentCustomer.currentBalance > 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444)),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
          _buildReminderBar(context),
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

  Widget _buildReminderBar(BuildContext context) {
    if (_currentCustomer.currentBalance <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildReminderButton(
              context,
              icon: FontAwesomeIcons.whatsapp,
              label: 'Remind',
              color: const Color(0xFF25D366),
              onTap: () => _handleReminder(context, isWhatsApp: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildReminderButton(
              context,
              icon: Icons.message,
              label: 'Remind',
              color: const Color(0xFF3B82F6),
              onTap: () => _handleReminder(context, isWhatsApp: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
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

  Widget _buildTransactionList(AppDatabase database) {
    return StreamBuilder<List<Transaction>>(
      stream: database.watchTransactionsForCustomer(_currentCustomer.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allTransactions = snapshot.data!;

        if (allTransactions.isEmpty) {
          return Center(
            child: Text(
              AppTranslations.get(
                Provider.of<LanguageProvider>(context).locale.languageCode,
                'no_transactions',
              ),
            ),
          );
        }

        // Grouping logic
        final List<Transaction> primaryTransactions = [];
        final Map<String, List<Transaction>> interestMap = {};

        for (final tx in allTransactions) {
          if (tx.isInterestEntry && tx.parentTransactionId != null) {
            interestMap.putIfAbsent(tx.parentTransactionId!, () => []).add(tx);
          } else {
            primaryTransactions.add(tx);
          }
        }

        // Sort primary transactions descending as they come from DB stream
        // (Assuming DB already sorts, but snapshot might be out of order if we weren't careful)
        // Actually, previous task ensured DB sorts desc.

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: primaryTransactions.length,
          itemBuilder: (context, index) {
            final tx = primaryTransactions[index];
            final prevTx = index > 0 ? primaryTransactions[index - 1] : null;
            final showYear = prevTx == null || tx.date.year != prevTx.date.year;

            final associatedInterests = interestMap[tx.id] ?? [];

            return Column(
              children: [
                if (showYear) _buildYearSeparator(tx.date.year.toString()),
                _buildExpandableTransactionItem(
                  context,
                  database,
                  tx,
                  associatedInterests,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildYearSeparator(String year) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1F2937)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          year,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF6B7280),
          ),
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
    if (associatedInterests.isEmpty) {
      return _buildTransactionItem(context, database, tx);
    }

    final totalInterest = associatedInterests.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );
    final netAmount = tx.amount + totalInterest;

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
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
                left: 16,
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
                          color: amountColor,
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
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B7280),
                        ),
                      ),
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
                                DateFormat('hh:mm a').format(tx.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(width: 6),
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
              children: associatedInterests
                  .map(
                    (interest) =>
                        _buildInterestSubItem(context, database, interest),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(Transaction tx) {
    Color badgeBgColor;
    Color badgeTextColor;
    Color badgeMonthColor;

    if (tx.isInterestEntry) {
      badgeBgColor = const Color(0xFF8B5CF6).withValues(alpha: 0.2);
      badgeTextColor = const Color(0xFF8B5CF6);
      badgeMonthColor = const Color(0xFF8B5CF6);
    } else if (Theme.of(context).brightness == Brightness.dark) {
      badgeBgColor = const Color(0xFF374151);
      badgeTextColor = Colors.white;
      badgeMonthColor = const Color(0xFF9CA3AF);
    } else {
      badgeBgColor = Colors.white;
      badgeTextColor = const Color(0xFF111827);
      badgeMonthColor = const Color(0xFF6B7280);
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: badgeBgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('dd').format(tx.date),
            style: TextStyle(
              fontSize: 18,
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
            Text(
              formatter.format(tx.amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: amountColor.withValues(alpha: 0.8),
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

    Color badgeBgColor;
    Color badgeTextColor;
    Color badgeMonthColor;

    if (tx.isInterestEntry) {
      // Distinct look for Interest Entries
      badgeBgColor = const Color(
        0xFF8B5CF6,
      ).withValues(alpha: 0.2); // Purple tint
      badgeTextColor = const Color(0xFF8B5CF6);
      badgeMonthColor = const Color(0xFF8B5CF6);
    } else if (Theme.of(context).brightness == Brightness.dark) {
      badgeBgColor = const Color(0xFF374151);
      badgeTextColor = Colors.white;
      badgeMonthColor = const Color(0xFF9CA3AF);
    } else {
      badgeBgColor = Colors.white; // White Badge on Gray Background
      badgeTextColor = const Color(0xFF111827); // Standard Text
      badgeMonthColor = const Color(0xFF6B7280); // Secondary Text
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: () => _showTransactionOptions(context, database, tx),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent, // Transparent to show Gray Scaffold BG
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB),
              ),
            ),
          ),
          padding: const EdgeInsets.only(
            left: 16,
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
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (tx.isInterestEntry)
                            const Icon(
                              Icons.percent,
                              size: 24,
                              color: Color(0xFF8B5CF6),
                            )
                          else ...[
                            Text(
                              DateFormat('dd').format(tx.date),
                              style: TextStyle(
                                fontSize: 18,
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
                    ),
                    const SizedBox(width: 16),
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
                                DateFormat('hh:mm a').format(tx.date),
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
                            ],
                          ),

                          // Reference Badge for Interest Entry
                          if (tx.isInterestEntry &&
                              tx.parentTransactionId != null) ...[
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(tx.amount),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
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
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7280),
                    ),
                  ),
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
    return Container(
      padding: const EdgeInsets.all(16),
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
                    '${AppTranslations.get(Provider.of<LanguageProvider>(context).locale.languageCode, 'you_got')} ₹',
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
  }) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: existingTransaction?.amount.toStringAsFixed(0) ?? '',
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
                  if (existingTransaction?.isInterestEntry != true)
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

                  double balanceAdjustment = 0;

                  if (existingTransaction != null) {
                    // Reverse old impact
                    balanceAdjustment -= (existingTransaction.type == 'GAVE'
                        ? existingTransaction.amount
                        : -existingTransaction.amount);
                    // Apply new impact
                    balanceAdjustment += (type == 'GAVE' ? amount : -amount);

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
                      ),
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
                      ),
                    );
                    balanceAdjustment = type == 'GAVE' ? amount : -amount;
                  }

                  final updatedCustomer = _currentCustomer.copyWith(
                    currentBalance:
                        _currentCustomer.currentBalance + balanceAdjustment,
                    lastUpdated: DateTime.now(),
                  );

                  await database.updateCustomer(updatedCustomer);

                  if (context.mounted) {
                    setState(() {
                      _currentCustomer = updatedCustomer;
                    });
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
