import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/localization/translations.dart';
import '../../../core/providers/language_provider.dart';

class ThemeSelectionDialog extends StatelessWidget {
  const ThemeSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return AlertDialog(
      title: Text(
        AppTranslations.get(
          Provider.of<LanguageProvider>(context).locale.languageCode,
          'select_theme',
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
          _buildThemeOption(
            context,
            themeProvider,
            mode: ThemeMode.light,
            label: AppTranslations.get(
              Provider.of<LanguageProvider>(context).locale.languageCode,
              'theme_light',
            ),
            icon: Icons.light_mode_outlined,
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context,
            themeProvider,
            mode: ThemeMode.dark,
            label: AppTranslations.get(
              Provider.of<LanguageProvider>(context).locale.languageCode,
              'theme_dark',
            ),
            icon: Icons.dark_mode_outlined,
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context,
            themeProvider,
            mode: ThemeMode.system,
            label: AppTranslations.get(
              Provider.of<LanguageProvider>(context).locale.languageCode,
              'theme_system',
            ),
            icon: Icons.settings_brightness_outlined,
          ),
        ],
      ),
      actions: [
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).cardColor,
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider provider, {
    required ThemeMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = provider.themeMode == mode;

    return InkWell(
      onTap: () {
        provider.setTheme(mode);
        Navigator.pop(context);
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
                : Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF111827),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                size: 20,
                color: Color(0xFF4F46E5),
              ),
          ],
        ),
      ),
    );
  }
}
