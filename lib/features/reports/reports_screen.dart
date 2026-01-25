import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/localization/translations.dart';
import '../../core/database/database.dart';
import 'components/date_range_selector.dart';
import 'components/financial_overview_cards.dart';
import 'components/cash_flow_chart.dart';
import 'components/balance_distribution_chart.dart';
import 'components/top_customers_chart.dart';
import 'components/quick_insights_section.dart';

enum DateRangeType {
  today,
  thisWeek,
  thisMonth,
  last30Days,
  last3Months,
  last6Months,
  thisYear,
  allTime,
  custom,
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateRangeType _selectedRange = DateRangeType.thisMonth;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isInitialLoad = true;

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final database = Provider.of<AppDatabase>(context);
    final dateRange = _getDateRange();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFEEF2FF)],
          ),
        ),
        child: Column(
          children: [
            // Custom Header
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: SizedBox(
                height: 60,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppTranslations.get(
                        langProvider.locale.languageCode,
                        'reports_insights',
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Body Content
            Expanded(
              child: FutureBuilder(
                future: _isInitialLoad
                    ? database.getFinancialOverview(dateRange.$1, dateRange.$2)
                    : null,
                builder: (context, snapshot) {
                  // Show loading screen on initial load
                  if (_isInitialLoad &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingScreen(context, langProvider);
                  }

                  // Mark initial load as complete
                  if (_isInitialLoad &&
                      snapshot.connectionState == ConnectionState.done) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _isInitialLoad = false;
                        });
                      }
                    });
                  }

                  // Show the actual content
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // Date Range Selector
                        DateRangeSelector(
                          selectedRange: _selectedRange,
                          customStartDate: _customStartDate,
                          customEndDate: _customEndDate,
                          onRangeChanged: (range, start, end) {
                            setState(() {
                              _selectedRange = range;
                              _customStartDate = start;
                              _customEndDate = end;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Financial Overview Cards
                        FinancialOverviewCards(
                          startDate: dateRange.$1,
                          endDate: dateRange.$2,
                        ),
                        const SizedBox(height: 24),
                        // Quick Insights
                        QuickInsightsSection(
                          startDate: dateRange.$1,
                          endDate: dateRange.$2,
                        ),
                        const SizedBox(height: 24),
                        // Top Customers
                        _buildSectionTitle(
                          context,
                          AppTranslations.get(
                            langProvider.locale.languageCode,
                            'top_customers',
                          ),
                          Icons.people_outline,
                        ),
                        const SizedBox(height: 12),
                        const TopCustomersChart(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(
    BuildContext context,
    LanguageProvider langProvider,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading indicator
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF4F46E5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            langProvider.locale.languageCode == 'hi'
                ? 'रिपोर्ट लोड हो रही है...'
                : langProvider.locale.languageCode == 'hinglish'
                ? 'Reports load ho rahi hain...'
                : 'Loading reports...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            langProvider.locale.languageCode == 'hi'
                ? 'कृपया प्रतीक्षा करें'
                : langProvider.locale.languageCode == 'hinglish'
                ? 'Kripya pratiksha karein'
                : 'Please wait',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF64748B)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case DateRangeType.today:
        return (
          DateTime(now.year, now.month, now.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case DateRangeType.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return (
          DateTime(weekStart.year, weekStart.month, weekStart.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case DateRangeType.thisMonth:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case DateRangeType.last30Days:
        return (now.subtract(const Duration(days: 30)), now);
      case DateRangeType.last3Months:
        return (DateTime(now.year, now.month - 3, now.day), now);
      case DateRangeType.last6Months:
        return (DateTime(now.year, now.month - 6, now.day), now);
      case DateRangeType.thisYear:
        return (DateTime(now.year, 1, 1), now);
      case DateRangeType.allTime:
        return (DateTime(2000, 1, 1), now);
      case DateRangeType.custom:
        return (
          _customStartDate ?? DateTime(now.year, now.month, 1),
          _customEndDate ?? now,
        );
    }
  }
}
