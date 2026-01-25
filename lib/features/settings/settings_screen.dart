import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/language_provider.dart';
import 'components/theme_selection_dialog.dart';
import 'components/language_selection_dialog.dart';
import 'components/factory_reset_dialog.dart';

import '../../core/localization/translations.dart';
import '../../core/services/backup_service.dart';
import '../../core/database/database.dart';
import '../reports/reports_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark =
        themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

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
            _buildHeader(context, isDark),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                children: [
                  _buildSection(
                    title: AppTranslations.get(
                      languageProvider.locale.languageCode,
                      'section_language',
                    ),
                    isDark: isDark,
                    children: [
                      _buildSettingItem(
                        icon: Icons.translate,
                        label: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'language_label',
                        ),
                        description: languageProvider.languageNativeName,
                        isDark: isDark,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                const LanguageSelectionDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                  _buildSection(
                    title: AppTranslations.get(
                      languageProvider.locale.languageCode,
                      'section_appearance',
                    ),
                    isDark: isDark,
                    children: [
                      _buildSettingItem(
                        icon: themeProvider.themeIcon,
                        label: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'theme_label',
                        ),
                        description: themeProvider.themeName,
                        isDark: isDark,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => const ThemeSelectionDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                  _buildSection(
                    title: AppTranslations.get(
                      languageProvider.locale.languageCode,
                      'section_analytics',
                    ),
                    isDark: isDark,
                    children: [
                      _buildSettingItem(
                        icon: Icons.bar_chart,
                        label: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'reports_label',
                        ),
                        description: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'reports_desc',
                        ),
                        isDark: isDark,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReportsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _buildSection(
                    title: AppTranslations.get(
                      languageProvider.locale.languageCode,
                      'section_data',
                    ),
                    isDark: isDark,
                    children: [
                      _buildSettingItem(
                        icon: Icons.download,
                        label: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'export_label',
                        ),
                        description: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'export_desc',
                        ),
                        isDark: isDark,
                        onTap: () async {
                          final database = Provider.of<AppDatabase>(
                            context,
                            listen: false,
                          );
                          final backupService = BackupService(database);
                          try {
                            await backupService.exportData();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Export failed: $e')),
                              );
                            }
                          }
                        },
                      ),
                      const _Divider(),
                      _buildSettingItem(
                        icon: Icons.upload,
                        label: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'import_label',
                        ),
                        description: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'import_desc',
                        ),
                        isDark: isDark,
                        onTap: () async {
                          final database = Provider.of<AppDatabase>(
                            context,
                            listen: false,
                          );
                          final backupService = BackupService(database);
                          try {
                            final result = await backupService.importData();
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Import Successful'),
                                  content: Text(
                                    'Added ${result['customers']} customers and ${result['transactions']} transactions.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Import failed: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  _buildSection(
                    title: AppTranslations.get(
                      languageProvider.locale.languageCode,
                      'section_danger',
                    ),
                    isDanger: true,
                    isDark: isDark,
                    children: [
                      _buildSettingItem(
                        icon: Icons.delete_forever,
                        label: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'factory_reset',
                        ),
                        description: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'reset_desc',
                        ),
                        iconColor: const Color(0xFFEF4444),
                        labelColor: const Color(0xFFEF4444),
                        isDark: isDark,
                        onTap: () => _showResetConfirmation(context),
                      ),
                    ],
                  ),
                  _buildSection(
                    title: AppTranslations.get(
                      languageProvider.locale.languageCode,
                      'section_about',
                    ),
                    isDark: isDark,
                    children: [
                      _buildSettingItem(
                        icon: Icons.info_outline,
                        label: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'version_label',
                        ),
                        description: '1.2.0',
                        isDark: isDark,
                        onTap: null,
                      ),
                      const _Divider(),
                      _buildSettingItem(
                        icon: Icons.help_outline,
                        label: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'help_label',
                        ),
                        description: AppTranslations.get(
                          languageProvider.locale.languageCode,
                          'help_desc',
                        ),
                        isDark: isDark,
                        onTap: () async {
                          final url = Uri.parse(
                            'https://raushanc107.github.io/Portfolio/',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.inAppWebView);
                          }
                        },
                        trailing: const Icon(
                          Icons.open_in_new,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 32),
                    child: Text(
                      AppTranslations.get(
                        languageProvider.locale.languageCode,
                        'made_with_love',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
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
                Provider.of<LanguageProvider>(context).locale.languageCode,
                'settings_title',
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
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    required bool isDark,
    Color? titleColor,
    bool isDanger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color:
                    titleColor ??
                    (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF6B7280)),
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDanger
                    ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                    : isDark
                    ? const Color(0xFF334155).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : const Color(0xFF000000).withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    required String description,
    required bool isDark,
    VoidCallback? onTap,
    Color? iconColor,
    Color? labelColor,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color:
                    iconColor ??
                    (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF4B5563)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            labelColor ??
                            (isDark ? Colors.white : const Color(0xFF111827)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFFE5E7EB),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FactoryResetDialog(),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
    );
  }
}
