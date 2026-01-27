import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderTemplateDialog extends StatefulWidget {
  const ReminderTemplateDialog({super.key});

  @override
  State<ReminderTemplateDialog> createState() => _ReminderTemplateDialogState();
}

class _ReminderTemplateDialogState extends State<ReminderTemplateDialog> {
  final TextEditingController _creditController = TextEditingController();
  bool _isLoading = true;

  static const String keyCredit = 'template_credit'; // You will get

  // Default templates
  static const String defaultCredit =
      "Hello {name}, your pending balance is {amount}. Please pay at your earliest convenience.";

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _creditController.text = prefs.getString(keyCredit) ?? defaultCredit;
      _isLoading = false;
    });
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCredit, _creditController.text);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Templates saved successfully')),
      );
    }
  }

  Future<void> _resetDefaults() async {
    setState(() {
      _creditController.text = defaultCredit;
    });
  }

  @override
  void dispose() {
    _creditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reminder Templates',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          tooltip: 'Reset to Default',
                          onPressed: _resetDefaults,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Payment Reminder Message', isDark),
                    const SizedBox(height: 8),
                    _buildTextField(_creditController, isDark),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Variables:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '{name} - Customer Name\n{amount} - Balance Amount',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveTemplates,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(color: Colors.white),
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

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, bool isDark) {
    return TextField(
      controller: controller,
      maxLines: 6,
      minLines: 3,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}
