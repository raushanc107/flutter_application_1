import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/localization/translations.dart';
import '../reports_screen.dart';

class DateRangeSelector extends StatelessWidget {
  final DateRangeType selectedRange;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final Function(DateRangeType, DateTime?, DateTime?) onRangeChanged;

  const DateRangeSelector({
    super.key,
    required this.selectedRange,
    required this.customStartDate,
    required this.customEndDate,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.get(langProvider.locale.languageCode, 'date_range'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B7280),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(context, DateRangeType.today, 'today'),
              _buildChip(context, DateRangeType.thisWeek, 'this_week'),
              _buildChip(context, DateRangeType.thisMonth, 'this_month'),
              _buildChip(context, DateRangeType.last30Days, 'last_30_days'),
              _buildChip(context, DateRangeType.last3Months, 'last_3_months'),
              _buildChip(context, DateRangeType.last6Months, 'last_6_months'),
              _buildChip(context, DateRangeType.thisYear, 'this_year'),
              _buildChip(context, DateRangeType.allTime, 'all_time'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    DateRangeType range,
    String labelKey,
  ) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isSelected = selectedRange == range;

    return InkWell(
      onTap: () => onRangeChanged(range, null, null),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Text(
          AppTranslations.get(langProvider.locale.languageCode, labelKey),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF374151)),
          ),
        ),
      ),
    );
  }
}
