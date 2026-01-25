import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/database/database.dart';
import '../../../../core/localization/translations.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/services/backup_service.dart';

class FactoryResetDialog extends StatelessWidget {
  const FactoryResetDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          Text(
            AppTranslations.get(
              languageProvider.locale.languageCode,
              'reset_confirm_title',
            ),
          ),
        ],
      ),
      content: Text(
        AppTranslations.get(
          languageProvider.locale.languageCode,
          'reset_confirm_msg',
        ),
      ),
      actions: [
        // Backup Button
        TextButton.icon(
          onPressed: () async {
            final database = Provider.of<AppDatabase>(context, listen: false);
            final backupService = BackupService(database);
            try {
              await backupService.exportData();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
              }
            }
          },
          icon: const Icon(Icons.download),
          label: Text(
            AppTranslations.get(
              languageProvider.locale.languageCode,
              'export_label',
            ),
          ),
        ),
        // Cancel Button
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppTranslations.get(languageProvider.locale.languageCode, 'cancel'),
          ),
        ),
        // Reset Button
        TextButton(
          onPressed: () async {
            final database = Provider.of<AppDatabase>(context, listen: false);
            await database.deleteAllData();
            if (context.mounted) {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back from settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data cleared successfully')),
              );
            }
          },
          child: Text(
            AppTranslations.get(
              languageProvider.locale.languageCode,
              'reset_btn',
            ),
            style: const TextStyle(color: Color(0xFFEF4444)),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
