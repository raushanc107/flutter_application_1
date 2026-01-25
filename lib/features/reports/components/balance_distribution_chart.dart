import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/localization/translations.dart';

class BalanceDistributionChart extends StatelessWidget {
  const BalanceDistributionChart({super.key});

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: database.getBalanceDistribution(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final customersOweYou = data['customersOweYou'] as int;
        final youOweCustomers = data['youOweCustomers'] as int;
        final settled = data['settled'] as int;
        final totalPositive = data['totalPositive'] as double;
        final totalNegative = data['totalNegative'] as double;

        final total = customersOweYou + youOweCustomers + settled;
        if (total == 0) {
          return Container(
            height: 300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Center(
              child: Text(
                AppTranslations.get(
                  langProvider.locale.languageCode,
                  'no_data_available',
                ),
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          );
        }

        final formatter = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        );

        return Container(
          height: 300,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              // Pie Chart
              Expanded(
                flex: 2,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    pieTouchData: PieTouchData(enabled: false),
                    borderData: FlBorderData(show: false),
                    sections: [
                      if (customersOweYou > 0)
                        PieChartSectionData(
                          color: const Color(0xFF10B981),
                          value: customersOweYou.toDouble(),
                          title: '$customersOweYou',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      if (youOweCustomers > 0)
                        PieChartSectionData(
                          color: const Color(0xFFEF4444),
                          value: youOweCustomers.toDouble(),
                          title: '$youOweCustomers',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      if (settled > 0)
                        PieChartSectionData(
                          color: const Color(0xFF6B7280),
                          value: settled.toDouble(),
                          title: '$settled',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          borderSide: BorderSide.none,
                        ),
                    ],
                  ),
                  duration: Duration.zero,
                ),
              ),
              const SizedBox(width: 16),
              // Legend
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (customersOweYou > 0)
                      _buildLegendItem(
                        context,
                        AppTranslations.get(
                          langProvider.locale.languageCode,
                          'customers_owe_you',
                        ),
                        formatter.format(totalPositive),
                        const Color(0xFF10B981),
                      ),
                    if (customersOweYou > 0) const SizedBox(height: 12),
                    if (youOweCustomers > 0)
                      _buildLegendItem(
                        context,
                        AppTranslations.get(
                          langProvider.locale.languageCode,
                          'you_owe_customers',
                        ),
                        formatter.format(totalNegative),
                        const Color(0xFFEF4444),
                      ),
                    if (youOweCustomers > 0) const SizedBox(height: 12),
                    if (settled > 0)
                      _buildLegendItem(
                        context,
                        AppTranslations.get(
                          langProvider.locale.languageCode,
                          'settled_customers',
                        ),
                        '$settled',
                        const Color(0xFF6B7280),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
