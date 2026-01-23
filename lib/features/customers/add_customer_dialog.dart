import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/translations.dart';
import '../../core/providers/language_provider.dart';
import '../../core/database/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

class AddCustomerDialog extends StatefulWidget {
  final Customer? customer;
  const AddCustomerDialog({super.key, this.customer});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name);
    _phoneController = TextEditingController(
      text: widget.customer?.phoneNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isEditing
            ? AppTranslations.get(lang, 'edit_customer')
            : AppTranslations.get(lang, 'new_customer'),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF111827),
        ),
      ),

      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppTranslations.get(lang, 'name_label'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppTranslations.get(lang, 'name_error');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: AppTranslations.get(lang, 'phone_label'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppTranslations.get(lang, 'cancel')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _submit,
          child: Text(
            isEditing
                ? AppTranslations.get(lang, 'save')
                : AppTranslations.get(lang, 'add'),
          ),
        ),
      ],
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final database = Provider.of<AppDatabase>(context, listen: false);

    if (widget.customer != null) {
      await database.updateCustomer(
        widget.customer!.copyWith(
          name: name,
          phoneNumber: phone,
          lastUpdated: DateTime.now(),
        ),
      );
    } else {
      final uuid = const Uuid().v4();
      await database.insertCustomer(
        CustomersCompanion(
          id: drift.Value(uuid),
          name: drift.Value(name),
          phoneNumber: drift.Value(phone),
          currentBalance: const drift.Value(0.0),
          lastUpdated: drift.Value(DateTime.now()),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
