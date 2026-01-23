import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/localization/translations.dart';

class LanguageSelectionDialog extends StatelessWidget {
  final bool isFirstLaunch;

  const LanguageSelectionDialog({super.key, this.isFirstLaunch = false});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        AppTranslations.get(
          Provider.of<LanguageProvider>(context).locale.languageCode,
          'select_language',
        ),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF111827),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageOption(
            context,
            languageProvider,
            code: 'en',
            label: 'English',
            nativeLabel: 'English',
            closeOnSelect: !isFirstLaunch,
          ),
          const SizedBox(height: 12),
          _buildLanguageOption(
            context,
            languageProvider,
            code: 'hi',
            label: 'Hindi',
            nativeLabel: 'हिंदी',
            closeOnSelect: !isFirstLaunch,
          ),
          const SizedBox(height: 12),
          _buildLanguageOption(
            context,
            languageProvider,
            code: 'hinglish',
            label: 'Hinglish',
            nativeLabel: 'Hinglish',
            closeOnSelect: !isFirstLaunch,
          ),
        ],
      ),
      actions: [
        if (isFirstLaunch)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppTranslations.get(
                  Provider.of<LanguageProvider>(context).locale.languageCode,
                  'continue',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppTranslations.get(
                Provider.of<LanguageProvider>(context).locale.languageCode,
                'cancel',
              ),
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    LanguageProvider provider, {
    required String code,
    required String label,
    required String nativeLabel,
    bool closeOnSelect = true,
  }) {
    final isSelected = provider.locale.languageCode == code;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        provider.setLanguage(Locale(code));
        if (closeOnSelect) {
          Navigator.pop(context);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5).withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : isDark
                ? const Color(0xFF334155)
                : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                    : isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Text(
                nativeLabel[0],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nativeLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : isDark
                          ? Colors.white
                          : const Color(0xFF111827),
                    ),
                  ),
                  if (label != nativeLabel) ...[
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                size: 24,
                color: Color(0xFF4F46E5),
              ),
          ],
        ),
      ),
    );
  }
}
