import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/database/database.dart';
import '../ledger/ledger_screen.dart';
import '../customers/add_customer_dialog.dart';
import 'package:intl/intl.dart';
import '../settings/settings_screen.dart';

import '../../core/providers/language_provider.dart';
import '../../core/localization/translations.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../settings/components/language_selection_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _filterType = 'All'; // 'All', 'GET', 'GIVE'
  String _sortType = 'balanceHighToLow';
  bool _showAlertsOnly = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (isFirstLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const LanguageSelectionDialog(isFirstLaunch: true),
        );
        prefs.setBool('is_first_launch', false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppTranslations.get(
                langProvider.locale.languageCode,
                'khatabook',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
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
      body: StreamBuilder<List<Transaction>>(
        stream: database.watchAllTransactions(),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading customer alerts: ${transactionSnapshot.error}',
                  style: const TextStyle(color: Color(0xFFEF4444)),
                ),
              ),
            );
          }
          if (!transactionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = transactionSnapshot.data!;
          return Column(
            children: [
              _buildSummaryCard(database, transactions),
              _buildSearchBar(),
              Expanded(child: _buildCustomerList(database, transactions)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const AddCustomerDialog(),
        ),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: Text(
          AppTranslations.get(langProvider.locale.languageCode, 'add_customer'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    AppDatabase database,
    List<Transaction> transactions,
  ) {
    return StreamBuilder<List<Customer>>(
      stream: database.watchAllCustomers(),
      builder: (context, snapshot) {
        // Debug logging
        debugPrint(
          'Summary Card - Connection State: ${snapshot.connectionState}',
        );
        debugPrint('Summary Card - Has Data: ${snapshot.hasData}');
        debugPrint('Summary Card - Has Error: ${snapshot.hasError}');
        if (snapshot.hasData) {
          debugPrint('Summary Card - Customer Count: ${snapshot.data!.length}');
        }
        if (snapshot.hasError) {
          debugPrint('Summary Card - Error: ${snapshot.error}');
        }

        // Handle error state
        if (snapshot.hasError) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF4444)),
            ),
            child: Text(
              'Error loading summary: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          );
        }

        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        // Handle no data (but not loading)
        if (!snapshot.hasData) {
          debugPrint('Summary Card - No data available');
          return const SizedBox.shrink();
        }

        double totalGet = 0;
        double totalGive = 0;

        for (final customer in snapshot.data!) {
          if (customer.isExcluded) continue; // Excluded from main summary
          if (customer.currentBalance > 0) {
            totalGet += customer.currentBalance;
          } else {
            totalGive += customer.currentBalance.abs();
          }
        }

        final netBalance = totalGet - totalGive;
        final formatter = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        );

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final customerAlerts = _getCustomerAlerts(transactions);
        final excludedCustomerIds = snapshot.data!
            .where((customer) => customer.isExcluded)
            .map((customer) => customer.id)
            .toSet();
        final alertCustomerCount = customerAlerts.keys
            .where((customerId) => !excludedCustomerIds.contains(customerId))
            .length;
        final languageCode = Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).locale.languageCode;

        return Container(
          margin: const EdgeInsets.all(16),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(
                      AppTranslations.get(
                        Provider.of<LanguageProvider>(
                          context,
                        ).locale.languageCode,
                        'net_balance',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatter.format(netBalance),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: netBalance.abs() < 0.01
                            ? const Color(0xFF6B7280)
                            : (netBalance > 0
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                color: isDark
                    ? const Color(0xFF334155).withValues(alpha: 0.3)
                    : const Color(0xFFE5E7EB).withValues(alpha: 0.5),
              ),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            AppTranslations.get(
                              Provider.of<LanguageProvider>(
                                context,
                              ).locale.languageCode,
                              'you_will_get',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatter.format(totalGet),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark
                        ? const Color(0xFF334155).withValues(alpha: 0.3)
                        : const Color(0xFFE5E7EB).withValues(alpha: 0.5),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            AppTranslations.get(
                              Provider.of<LanguageProvider>(
                                context,
                              ).locale.languageCode,
                              'you_will_give',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatter.format(totalGive),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (alertCustomerCount > 0 || _showAlertsOnly) ...[
                Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF334155).withValues(alpha: 0.5)
                      : const Color(0xFFE5E7EB),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showAlertsOnly = !_showAlertsOnly;
                      });
                    },
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFA76513),
                              ),
                            ),
                            child: Text(
                              alertCustomerCount.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              AppTranslations.get(
                                languageCode,
                                _showAlertsOnly
                                    ? 'showing_customers_needing_attention'
                                    : alertCustomerCount == 1
                                    ? 'customer_needs_attention_label'
                                    : 'customers_need_attention_label',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_showAlertsOnly) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '·',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppTranslations.get(
                                languageCode,
                                'show_all_short',
                              ),
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: AppTranslations.get(
            Provider.of<LanguageProvider>(context).locale.languageCode,
            'search_placeholder',
          ),
          hintStyle: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF9CA3AF),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF9CA3AF),
          ),
          suffixIcon: PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list,
              color: _filterType == 'All' && _sortType == 'balanceHighToLow'
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF9CA3AF))
                  : const Color(0xFF4F46E5),
            ),
            onSelected: (String value) {
              setState(() {
                if (value.startsWith('sort:')) {
                  _sortType = value.substring('sort:'.length);
                } else {
                  _filterType = value;
                }
              });
            },
            itemBuilder: (BuildContext context) {
              final languageCode = Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).locale.languageCode;
              return <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  height: 32,
                  child: Text(
                    AppTranslations.get(languageCode, 'filter_customers'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                _buildFilterSortOption(
                  'All',
                  AppTranslations.get(languageCode, 'all_customers'),
                  _filterType == 'All',
                ),
                _buildFilterSortOption(
                  'GET',
                  AppTranslations.get(languageCode, 'you_will_get'),
                  _filterType == 'GET',
                ),
                _buildFilterSortOption(
                  'GIVE',
                  AppTranslations.get(languageCode, 'you_will_give'),
                  _filterType == 'GIVE',
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  enabled: false,
                  height: 32,
                  child: Text(
                    AppTranslations.get(languageCode, 'sort_by'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                _buildFilterSortOption(
                  'sort:balanceHighToLow',
                  AppTranslations.get(languageCode, 'sort_balance_high_to_low'),
                  _sortType == 'balanceHighToLow',
                ),
                _buildFilterSortOption(
                  'sort:balanceLowToHigh',
                  AppTranslations.get(languageCode, 'sort_balance_low_to_high'),
                  _sortType == 'balanceLowToHigh',
                ),
                _buildFilterSortOption(
                  'sort:nameAToZ',
                  AppTranslations.get(languageCode, 'sort_name_a_to_z'),
                  _sortType == 'nameAToZ',
                ),
                _buildFilterSortOption(
                  'sort:nameZToA',
                  AppTranslations.get(languageCode, 'sort_name_z_to_a'),
                  _sortType == 'nameZToA',
                ),
              ];
            },
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildFilterSortOption(
    String value,
    String label,
    bool selected,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          if (selected)
            const Icon(Icons.check, size: 18, color: Color(0xFF4F46E5))
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildCustomerList(
    AppDatabase database,
    List<Transaction> transactions,
  ) {
    return StreamBuilder<List<Customer>>(
      stream: database.watchAllCustomers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var customers = snapshot.data ?? [];
        final customerAlerts = _getCustomerAlerts(transactions);

        // Apply type filter
        if (_filterType == 'GET') {
          customers = customers.where((c) => c.currentBalance > 0).toList();
        } else if (_filterType == 'GIVE') {
          customers = customers.where((c) => c.currentBalance < 0).toList();
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          customers = customers
              .where((c) => c.name.toLowerCase().contains(_searchQuery))
              .toList();
        }
        if (_showAlertsOnly) {
          customers = customers
              .where(
                (customer) =>
                    !customer.isExcluded &&
                    customerAlerts.containsKey(customer.id),
              )
              .toList();
        }
        customers.sort((a, b) {
          final aHasBalance = a.currentBalance.abs() >= 0.01;
          final bHasBalance = b.currentBalance.abs() >= 0.01;
          final aGroup = !aHasBalance ? 2 : (a.isExcluded ? 1 : 0);
          final bGroup = !bHasBalance ? 2 : (b.isExcluded ? 1 : 0);
          final groupComparison = aGroup.compareTo(bGroup);
          if (groupComparison != 0) return groupComparison;

          final nameComparison = a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          );
          if (!aHasBalance) return nameComparison;

          final balanceComparison = b.currentBalance.abs().compareTo(
            a.currentBalance.abs(),
          );
          switch (_sortType) {
            case 'balanceLowToHigh':
              final amountComparison = a.currentBalance.abs().compareTo(
                b.currentBalance.abs(),
              );
              return amountComparison != 0 ? amountComparison : nameComparison;
            case 'nameAToZ':
              return nameComparison != 0 ? nameComparison : balanceComparison;
            case 'nameZToA':
              final reverseNameComparison = b.name.toLowerCase().compareTo(
                a.name.toLowerCase(),
              );
              return reverseNameComparison != 0
                  ? reverseNameComparison
                  : balanceComparison;
            default:
              return balanceComparison != 0
                  ? balanceComparison
                  : nameComparison;
          }
        });

        if (customers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty ||
                          _filterType != 'All' ||
                          _showAlertsOnly
                      ? AppTranslations.get(
                          Provider.of<LanguageProvider>(
                            context,
                          ).locale.languageCode,
                          'no_results_found',
                        )
                      : AppTranslations.get(
                          Provider.of<LanguageProvider>(
                            context,
                          ).locale.languageCode,
                          'no_customers',
                        ),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Changed from crossAxisAlignment: CrossAxisAlignment.start to default center for safety or keep structure
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    _showAlertsOnly
                        ? '${customers.length} ${AppTranslations.get(Provider.of<LanguageProvider>(context).locale.languageCode, 'customers_needing_attention')}'
                        : '${customers.length} ${AppTranslations.get(Provider.of<LanguageProvider>(context).locale.languageCode, 'customers_label')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  return _buildCustomerItem(
                    customer,
                    customerAlerts[customer.id] ?? const [],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, List<_CustomerAlert>> _getCustomerAlerts(
    List<Transaction> transactions,
  ) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final alertsByCustomer = <String, List<_CustomerAlert>>{};

    for (final transaction in transactions) {
      if (transaction.isPaid || transaction.isExcluded) continue;

      final isInterest = transaction.isInterestEntry == true;
      final isRecurring =
          transaction.parentTransactionId != null &&
          !transaction.isRecurringParent;
      if (!isInterest && !isRecurring) continue;

      final dueDate = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      if (isInterest
          ? dueDate.isAfter(startOfToday)
          : !dueDate.isBefore(startOfToday)) {
        continue;
      }

      alertsByCustomer
          .putIfAbsent(transaction.customerId, () => [])
          .add(
            _CustomerAlert(
              daysOverdue: startOfToday.difference(dueDate).inDays,
            ),
          );
    }

    return alertsByCustomer;
  }

  Widget _buildCustomerItem(Customer customer, List<_CustomerAlert> alerts) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final balance = customer.currentBalance;
    final isZero = balance.abs() < 0.01;
    final isGet = balance > 0;
    final color = isZero
        ? const Color(0xFF6B7280)
        : (isGet ? const Color(0xFF10B981) : const Color(0xFFEF4444));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageCode = Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).locale.languageCode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LedgerScreen(customer: customer),
                ),
              );
            },
            onLongPress: () {
              final database = Provider.of<AppDatabase>(context, listen: false);
              _showCustomerOptions(context, database, customer);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isDark
                        ? const Color(0xFF312E81)
                        : const Color(0xFFE0E7FF),
                    foregroundColor: isDark
                        ? const Color(0xFF818CF8)
                        : const Color(0xFF4F46E5),
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              DateFormat(
                                'dd MMM yyyy',
                              ).format(customer.lastUpdated),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                            if (customer.isExcluded) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.15),
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (alerts.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Builder(
                            builder: (context) {
                              final overdueCount = alerts
                                  .where((alert) => alert.daysOverdue > 0)
                                  .length;
                              final dueTodayCount =
                                  alerts.length - overdueCount;
                              final hasOverdue = overdueCount > 0;
                              final alertColor = hasOverdue
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFF59E0B);
                              final summary =
                                  AppTranslations.get(
                                    languageCode,
                                    hasOverdue
                                        ? 'alerts_overdue_count'
                                        : 'alerts_due_today_only',
                                  ).replaceFirst(
                                    '{count}',
                                    (hasOverdue ? overdueCount : dueTodayCount)
                                        .toString(),
                                  );

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: alertColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: alertColor.withValues(
                                            alpha: 0.55,
                                          ),
                                          width: 0.7,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              summary,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: alertColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (hasOverdue && dueTodayCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        AppTranslations.get(
                                          languageCode,
                                          'alerts_due_today_count',
                                        ).replaceFirst(
                                          '{count}',
                                          dueTodayCount.toString(),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatter.format(customer.currentBalance.abs()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTranslations.get(
                          Provider.of<LanguageProvider>(
                            context,
                          ).locale.languageCode,
                          isZero
                              ? 'no_due'
                              : (isGet ? 'ledger_get' : 'ledger_give'),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomerOptions(
    BuildContext context,
    AppDatabase database,
    Customer customer,
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
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF312E81)
                        : const Color(0xFFE0E7FF),
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF818CF8)
                        : const Color(0xFF4F46E5),
                    child: Text(customer.name[0].toUpperCase()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          customer.phoneNumber.isNotEmpty == true
                              ? customer.phoneNumber
                              : AppTranslations.get(
                                  Provider.of<LanguageProvider>(
                                    context,
                                  ).locale.languageCode,
                                  'no_phone_number',
                                ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(
                AppTranslations.get(
                  Provider.of<LanguageProvider>(context).locale.languageCode,
                  'edit_customer',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AddCustomerDialog(customer: customer),
                );
              },
            ),
            ListTile(
              leading: Icon(
                customer.isExcluded
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFFF59E0B),
              ),
              title: Text(
                AppTranslations.get(
                  Provider.of<LanguageProvider>(context).locale.languageCode,
                  customer.isExcluded
                      ? 'include_in_summary'
                      : 'exclude_from_summary',
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await database.updateCustomer(
                  customer.copyWith(
                    isExcluded: !customer.isExcluded,
                    lastUpdated: DateTime.now(),
                  ),
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
                  'delete_customer',
                ),
                style: const TextStyle(color: Color(0xFFEF4444)),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, database, customer);
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
    Customer customer,
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
            'delete_customer_title',
          ),
        ),
        content: Text(
          AppTranslations.get(
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).locale.languageCode,
            'delete_customer_msg',
          ).replaceFirst('{name}', customer.name),
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
            onPressed: () async {
              await database.deleteCustomer(customer);
              if (context.mounted) Navigator.pop(context);
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _CustomerAlert {
  final int daysOverdue;

  const _CustomerAlert({required this.daysOverdue});
}
