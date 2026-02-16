import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/pdf_config.dart';

class PdfConfigDialog extends StatefulWidget {
  const PdfConfigDialog({super.key});

  @override
  State<PdfConfigDialog> createState() => _PdfConfigDialogState();
}

class _PdfConfigDialogState extends State<PdfConfigDialog> {
  DateRange _selectedDateRange = DateRange.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _includeTransactionDetails = true;
  bool _summaryOnly = false;
  bool _includeInterest = true;
  bool _includePaymentHistory = true;
  bool _includeContactInfo = true;
  bool _includePaidPayments = false;

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd MMM yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF818CF8)
                          : const Color(0xFF4F46E5),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Export PDF Report',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Date Range Section
                _buildSectionTitle('Date Range'),
                const SizedBox(height: 12),
                _buildDateRangeOption('All Transactions', DateRange.all),
                _buildDateRangeOption('Last 30 Days', DateRange.last30Days),
                _buildDateRangeOption('Last 3 Months', DateRange.last3Months),
                _buildDateRangeOption('Last 6 Months', DateRange.last6Months),
                _buildDateRangeOption('Last Year', DateRange.lastYear),
                _buildDateRangeOption('Custom Range', DateRange.custom),

                // Custom Date Pickers
                if (_selectedDateRange == DateRange.custom) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker(
                          'Start Date',
                          _customStartDate,
                          (date) => setState(() => _customStartDate = date),
                          dateFormatter,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDatePicker(
                          'End Date',
                          _customEndDate,
                          (date) => setState(() => _customEndDate = date),
                          dateFormatter,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Report Content Section - Collapsible
                ExpansionTile(
                  title: Text(
                    'Report Content Options',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF818CF8)
                          : const Color(0xFF4F46E5),
                    ),
                  ),
                  subtitle: const Text(
                    'Tap to customize report content',
                    style: TextStyle(fontSize: 12),
                  ),
                  initiallyExpanded: false,
                  children: [
                    _buildCheckboxOption(
                      'Include Transaction Details',
                      _includeTransactionDetails,
                      (value) => setState(() {
                        _includeTransactionDetails = value!;
                        if (!value) _summaryOnly = true;
                      }),
                    ),
                    _buildCheckboxOption(
                      'Summary Only',
                      _summaryOnly,
                      (value) => setState(() {
                        _summaryOnly = value!;
                        if (value) _includeTransactionDetails = false;
                      }),
                    ),
                    _buildCheckboxOption(
                      'Include Interest Calculations',
                      _includeInterest,
                      (value) => setState(() => _includeInterest = value!),
                    ),
                    _buildCheckboxOption(
                      'Include Payment History',
                      _includePaymentHistory,
                      (value) =>
                          setState(() => _includePaymentHistory = value!),
                    ),
                    _buildCheckboxOption(
                      'Include Contact Information',
                      _includeContactInfo,
                      (value) => setState(() => _includeContactInfo = value!),
                    ),
                    _buildCheckboxOption(
                      'Include Paid Payments',
                      _includePaidPayments,
                      (value) => setState(() => _includePaidPayments = value!),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isConfigValid() ? _generateReport : null,
                      icon: const Icon(Icons.file_download),
                      label: const Text('Generate Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF818CF8)
            : const Color(0xFF4F46E5),
      ),
    );
  }

  Widget _buildDateRangeOption(String label, DateRange value) {
    return RadioListTile<DateRange>(
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF111827),
        ),
      ),
      value: value,
      groupValue: _selectedDateRange,
      onChanged: (DateRange? newValue) {
        setState(() {
          _selectedDateRange = newValue!;
        });
      },
      activeColor: const Color(0xFF4F46E5),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? date,
    Function(DateTime?) onDateSelected,
    DateFormat formatter,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date != null ? formatter.format(date) : label,
              style: TextStyle(
                fontSize: 13,
                color: date != null
                    ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF111827))
                    : const Color(0xFF9CA3AF),
              ),
            ),
            Icon(
              Icons.calendar_today,
              size: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxOption(
    String label,
    bool value,
    Function(bool?) onChanged,
  ) {
    return CheckboxListTile(
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF111827),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF4F46E5),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  bool _isConfigValid() {
    if (_selectedDateRange == DateRange.custom) {
      return _customStartDate != null && _customEndDate != null;
    }
    return true;
  }

  void _generateReport() {
    final config = PdfConfig(
      dateRange: _selectedDateRange,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
      includeTransactionDetails: _includeTransactionDetails,
      summaryOnly: _summaryOnly,
      includeInterest: _includeInterest,
      includePaymentHistory: _includePaymentHistory,
      includeContactInfo: _includeContactInfo,
      includePaidPayments: _includePaidPayments,
      languageCode: 'en',
    );

    Navigator.pop(context, config);
  }
}
