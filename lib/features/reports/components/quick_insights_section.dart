import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/localization/translations.dart';

class QuickInsightsSection extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;

  const QuickInsightsSection({
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
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final insights = _generateInsights(context, data, langProvider);

        if (insights.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppTranslations.get(
                      langProvider.locale.languageCode,
                      'quick_insights',
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16, right: 16),
                clipBehavior: Clip.none,
                itemCount: insights.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == insights.length - 1 ? 0 : 12,
                    ),
                    child: _buildInsightCard(
                      context,
                      insights[index]['icon'] as IconData,
                      insights[index]['text'] as String,
                      insights[index]['color'] as Color,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _generateInsights(
    BuildContext context,
    Map<String, dynamic> data,
    LanguageProvider langProvider,
  ) {
    final insights = <Map<String, dynamic>>[];
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final totalTransactions = data['totalTransactions'] as int;
    final totalGiven = data['totalGiven'] as double;
    final totalReceived = data['totalReceived'] as double;
    final activeCustomers = data['activeCustomers'] as int;
    final totalCustomers = data['totalCustomers'] as int;
    final totalOutstanding = data['totalOutstanding'] as double;

    // Insight 1: Transaction activity
    if (totalTransactions > 0) {
      insights.add({
        'icon': Icons.receipt_long,
        'text': langProvider.locale.languageCode == 'hi'
            ? '$totalTransactions लेनदेन इस अवधि में'
            : langProvider.locale.languageCode == 'hinglish'
            ? '$totalTransactions transactions is period mein'
            : '$totalTransactions transactions in this period',
        'color': const Color(0xFF4F46E5),
      });
    }

    // Insight 2: Outstanding balance
    if (totalOutstanding.abs() > 0.01) {
      final isPositive = totalOutstanding > 0;
      insights.add({
        'icon': isPositive ? Icons.trending_up : Icons.trending_down,
        'text': langProvider.locale.languageCode == 'hi'
            ? '${formatter.format(totalOutstanding.abs())} ${isPositive ? 'प्राप्त करना है' : 'देना है'}'
            : langProvider.locale.languageCode == 'hinglish'
            ? '${formatter.format(totalOutstanding.abs())} ${isPositive ? 'lena hai' : 'dena hai'}'
            : '${formatter.format(totalOutstanding.abs())} ${isPositive ? 'to receive' : 'to pay'}',
        'color': isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      });
    }

    // Insight 3: Active customers ratio
    if (totalCustomers > 0) {
      final activePercentage = ((activeCustomers / totalCustomers) * 100)
          .toInt();
      insights.add({
        'icon': Icons.people,
        'text': langProvider.locale.languageCode == 'hi'
            ? '$activePercentage% ग्राहक सक्रिय'
            : langProvider.locale.languageCode == 'hinglish'
            ? '$activePercentage% customers active'
            : '$activePercentage% customers active',
        'color': const Color(0xFF8B5CF6),
      });
    }

    // Insight 4: Cash flow balance
    if (totalGiven > 0 || totalReceived > 0) {
      final netFlow = totalReceived - totalGiven;
      if (netFlow.abs() > 0.01) {
        insights.add({
          'icon': netFlow > 0 ? Icons.arrow_downward : Icons.arrow_upward,
          'text': langProvider.locale.languageCode == 'hi'
              ? '${formatter.format(netFlow.abs())} ${netFlow > 0 ? 'अधिक प्राप्त' : 'अधिक दिया'}'
              : langProvider.locale.languageCode == 'hinglish'
              ? '${formatter.format(netFlow.abs())} ${netFlow > 0 ? 'zyada mila' : 'zyada diya'}'
              : '${formatter.format(netFlow.abs())} ${netFlow > 0 ? 'more received' : 'more given'}',
          'color': netFlow > 0
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
        });
      }
    }

    // Insight 5: Average transaction
    final avgTransaction = data['avgTransaction'] as double;
    if (avgTransaction > 0) {
      insights.add({
        'icon': Icons.analytics,
        'text': langProvider.locale.languageCode == 'hi'
            ? 'औसत: ${formatter.format(avgTransaction)}'
            : langProvider.locale.languageCode == 'hinglish'
            ? 'Average: ${formatter.format(avgTransaction)}'
            : 'Avg: ${formatter.format(avgTransaction)}',
        'color': const Color(0xFF06B6D4),
      });
    }

    return insights.take(5).toList();
  }

  Widget _buildInsightCard(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
