import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/services/backup_manager.dart';
import '../../core/services/google_drive_auth_service.dart';
import '../../core/providers/theme_provider.dart';
import 'package:intl/intl.dart';
import 'components/restore_backup_dialog.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
              child: Consumer2<BackupManager, GoogleDriveAuthService>(
                builder: (context, backupManager, authService, child) {
                  final user = authService.currentUser;
                  final isConnected = user != null;

                  if (!isConnected) {
                    return _buildConnectView(context, isDark, authService);
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    children: [
                      _buildAccountCard(context, user, isDark, authService),
                      const SizedBox(height: 24),
                      _buildSettingsSection(context, backupManager, isDark),
                      const SizedBox(height: 24),
                      _buildActionsSection(context, backupManager, isDark),
                      const SizedBox(height: 24),
                      _buildStatusSection(context, backupManager, isDark),
                    ],
                  );
                },
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
              'Google Drive Backup',
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

  Widget _buildConnectView(
    BuildContext context,
    bool isDark,
    GoogleDriveAuthService authService,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 80,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 24),
            Text(
              'Secure Cloud Backup',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your Google Drive to automatically backup your data and keep it safe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await authService.signIn();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Connection failed: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('Connect Google Drive'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    GoogleSignInAccount user,
    bool isDark,
    GoogleDriveAuthService authService,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundImage: user.photoUrl != null
              ? NetworkImage(user.photoUrl!)
              : null,
          child: user.photoUrl == null
              ? Text(user.email[0].toUpperCase())
              : null,
        ),
        title: Text(
          user.displayName ?? 'Google User',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          user.email,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.logout, color: Colors.red),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Disconnect Account?'),
                content: const Text(
                  'Auto-backup will be disabled. Your existing backups on Drive will remain.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await authService.signOut();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    BackupManager manager,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            'SETTINGS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (kIsWeb)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Auto-backup is only available on the mobile app.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                SwitchListTile(
                  title: const Text('Auto Backup'),
                  subtitle: const Text(
                    'Automatically backup data periodically',
                  ),
                  value: manager.autoBackupEnabled,
                  onChanged: (value) => manager.updateSettings(enabled: value),
                  activeThumbColor: Theme.of(context).primaryColor,
                ),
                if (manager.autoBackupEnabled) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    title: const Text('Frequency'),
                    trailing: DropdownButton<String>(
                      value: manager.frequency,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          manager.updateSettings(frequency: value);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: const Text('WiFi Only'),
                    subtitle: const Text('Backup only when connected to WiFi'),
                    value: manager.wifiOnly,
                    onChanged: (value) =>
                        manager.updateSettings(wifiOnly: value),
                    activeThumbColor: Theme.of(context).primaryColor,
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(
    BuildContext context,
    BackupManager manager,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            'ACTIONS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('Backup Now'),
                trailing: manager.isBackingUp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: manager.isBackingUp
                    ? null
                    : () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Starting backup...')),
                        );
                        final error = await manager.performBackup();
                        if (context.mounted) {
                          if (error == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Backup successful!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Backup failed: $error'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore from Drive'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const RestoreBackupDialog(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    BackupManager manager,
    bool isDark,
  ) {
    if (manager.lastBackupTime == null) return const SizedBox.shrink();

    final dateFormat = DateFormat.yMMMd().add_jm();
    final statusColor = manager.lastBackupStatus == 'success'
        ? Colors.green
        : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            manager.lastBackupStatus == 'success'
                ? Icons.check_circle_outline
                : Icons.error_outline,
            color: statusColor,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                manager.lastBackupStatus == 'success'
                    ? 'Last Backup Successful'
                    : 'Last Backup Failed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateFormat.format(manager.lastBackupTime!),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
