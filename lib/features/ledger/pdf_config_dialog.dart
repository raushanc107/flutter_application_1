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
  StatementType _type = StatementType.full;

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
                        'Export PDF',
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

                // Statement type
                _buildSectionTitle('Statement Type'),
                const SizedBox(height: 8),
                _buildTypeOption(
                  'Full Statement',
                  'All transactions with running balance, interest and '
                      'recurring details',
                  StatementType.full,
                ),
                _buildTypeOption(
                  'Payment Request',
                  'Only pending interest and recurring payments, to send to '
                      'the customer',
                  StatementType.paymentRequest,
                ),
                const SizedBox(height: 16),

                if (_type == StatementType.full) ...[
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
                ] else
                  Text(
                    'Lists everything pending as of today. No date range needed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
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
                      label: const Text('Generate PDF'),
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

  Widget _buildTypeOption(String title, String subtitle, StatementType value) {
    return RadioListTile<StatementType>(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF111827),
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      groupValue: _type,
      onChanged: (v) => setState(() => _type = v!),
      activeColor: const Color(0xFF4F46E5),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  bool _isConfigValid() {
    if (_type == StatementType.full && _selectedDateRange == DateRange.custom) {
      return _customStartDate != null && _customEndDate != null;
    }
    return true;
  }

  void _generateReport() {
    final config = PdfConfig(
      type: _type,
      dateRange: _selectedDateRange,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
    );

    Navigator.pop(context, config);
  }
}
