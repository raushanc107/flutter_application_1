import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/localization/translations.dart';

class FinancialOverviewCards extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;

  const FinancialOverviewCards({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: database.getFinancialOverview(startDate, endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final formatter = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get(
                  langProvider.locale.languageCode,
                  'financial_overview',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B7280),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.7,
                children: [
                  _buildMetricCard(
                    context,
                    AppTranslations.get(
                      langProvider.locale.languageCode,
                      'total_outstanding',
                    ),
                    formatter.format(data['totalOutstanding']),
                    Icons.account_balance_wallet_outlined,
                    (data['totalOutstanding'] as double) >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                  _buildMetricCard(
                    context,
                    AppTranslations.get(
                      langProvider.locale.languageCode,
                      'total_transactions',
                    ),
                    '${data['totalTransactions']}',
                    Icons.receipt_long_outlined,
                    const Color(0xFF4F46E5),
                  ),
                  _buildMetricCard(
                    context,
                    AppTranslations.get(
                      langProvider.locale.languageCode,
                      'active_customers',
                    ),
                    '${data['activeCustomers']}/${data['totalCustomers']}',
                    Icons.people_outline,
                    const Color(0xFF8B5CF6),
                  ),
                  _buildMetricCard(
                    context,
                    AppTranslations.get(
                      langProvider.locale.languageCode,
                      'avg_transaction',
                    ),
                    formatter.format(data['avgTransaction']),
                    Icons.trending_up,
                    const Color(0xFF06B6D4),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 20, color: color.withOpacity(0.6)),
            ],
          ),
        ],
      ),
    );
  }
}
