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
      body: Column(
        children: [
          _buildSummaryCard(database),
          _buildSearchBar(),
          Expanded(child: _buildCustomerList(database)),
        ],
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

  Widget _buildSummaryCard(AppDatabase database) {
    return StreamBuilder<List<Customer>>(
      stream: database.watchAllCustomers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        double totalGet = 0;
        double totalGive = 0;

        for (final customer in snapshot.data!) {
          if (customer.currentBalance > 0) {
            totalGet += customer.currentBalance;
          } else {
            totalGive += customer.currentBalance.abs();
          }
        }

        final netBalance = totalGet - totalGive;
        final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE5E7EB),
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE5E7EB),
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

  Widget _buildCustomerList(AppDatabase database) {
    return StreamBuilder<List<Customer>>(
      stream: database.watchAllCustomers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var customers = snapshot.data ?? [];
        if (_searchQuery.isNotEmpty) {
          customers = customers
              .where((c) => c.name.toLowerCase().contains(_searchQuery))
              .toList();
        }

        if (customers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  AppTranslations.get(
                    Provider.of<LanguageProvider>(context).locale.languageCode,
                    'no_customers',
                  ),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '${customers.length} ${AppTranslations.get(Provider.of<LanguageProvider>(context).locale.languageCode, 'customers_label')}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B7280),
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  return _buildCustomerItem(customer);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomerItem(Customer customer) {
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final balance = customer.currentBalance;
    final isZero = balance.abs() < 0.01;
    final isGet = balance > 0;
    final color = isZero
        ? const Color(0xFF6B7280)
        : (isGet ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : const Color(0xFFE5E7EB),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF312E81)
                : const Color(0xFFE0E7FF),
            foregroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF818CF8)
                : const Color(0xFF4F46E5),
            child: Text(
              customer.name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            customer.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            DateFormat('dd MMM yyyy').format(customer.lastUpdated),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          trailing: Column(
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
              Text(
                AppTranslations.get(
                  Provider.of<LanguageProvider>(context).locale.languageCode,
                  isZero ? 'no_due' : (isGet ? 'ledger_get' : 'ledger_give'),
                ),
                style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
              ),
            ],
          ),
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
