import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/database/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../core/providers/language_provider.dart';
import '../../core/localization/translations.dart';

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
      body: Stack(
        children: [
          _buildTransactionList(database),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomActionButtons(context, database),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(AppDatabase database) {
    return StreamBuilder<List<Transaction>>(
      stream: database.watchTransactionsForCustomer(_currentCustomer.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data!.reversed.toList();

        if (transactions.isEmpty) {
          return Center(
            child: Text(
              AppTranslations.get(
                Provider.of<LanguageProvider>(context).locale.languageCode,
                'no_transactions',
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final prevTx = index > 0 ? transactions[index - 1] : null;
            final showYear = prevTx == null || tx.date.year != prevTx.date.year;

            return Column(
              children: [
                if (showYear) _buildYearSeparator(tx.date.year.toString()),
                _buildTransactionItem(context, database, tx),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: () => _showTransactionOptions(context, database, tx),
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
          padding: const EdgeInsets.all(16),
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF374151)
                            : const Color(0xFFF3F4F6),
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
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(tx.date).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
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
                          Row(
                            children: [
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
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(tx.amount),
                    style: TextStyle(
                      fontSize: 18,
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
                      fontSize: 10,
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
    // Reverse the balance impact
    // Reverse the balance impact: If GAVE (+), subtract. If GOT (-), add.
    final balanceAdjustment = tx.type == 'GAVE' ? -tx.amount : tx.amount;
    final newBalance = _currentCustomer.currentBalance + balanceAdjustment;

    await database.deleteTransaction(tx);

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

    DateTime selectedDate = existingTransaction?.date ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountController,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                  ],
                ),
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
                    // Reverse old impact: If Old was GAVE (+), subtract. If GOT (-), add.
                    balanceAdjustment -= (existingTransaction.type == 'GAVE'
                        ? existingTransaction.amount
                        : -existingTransaction.amount);
                    // Apply new impact: If New is GAVE (+), add. If GOT (-), subtract.
                    balanceAdjustment += (type == 'GAVE' ? amount : -amount);

                    await database.updateTransaction(
                      existingTransaction.copyWith(
                        amount: amount,
                        date: finalDateTime,
                        notes: drift.Value(notes),
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
