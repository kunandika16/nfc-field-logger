import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../services/sync_service.dart';
import '../services/database_helper.dart';
import '../utils/app_theme.dart';
import '../services/user_profile_service.dart';
import '../services/google_sheets_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SyncService _syncService = SyncService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final GoogleSheetsService _googleSheetsService = GoogleSheetsService();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _spreadsheetUrlController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final UserProfileService _userProfileService = UserProfileService();

  // Default Google Apps Script URL
  static const String defaultAppScriptUrl =
      'https://script.google.com/macros/s/AKfycbw0X-aUMO6-09o0fJ1yWl1d-sTMI2EUQ5mpO8SKR1oCIZhSkvwnGqrKVtdbAqSB5Q2KbA/exec';

  bool _isLoading = true;
  bool _isTesting = false;
  bool _isEditingUrl = false;
  bool _isEditingSpreadsheetUrl = false;
  bool _autoSyncEnabled = true;
  String? _lastSyncTime;
  int _totalLogs = 0;
  int _unsyncedLogs = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final url = await _syncService.getWebAppUrl();
    final spreadsheetUrl = await _syncService.getSpreadsheetUrl();
    final autoSync = await _syncService.isAutoSyncEnabled();
    final lastSync = _syncService.lastSyncTime;
    final total = await _dbHelper.getTotalScanCount();
    final unsynced = await _dbHelper.getUnsyncedCount();

    // Load user profile
    final userName = await _userProfileService.getUserName();
    final userClass = await _userProfileService.getUserClass();
    _nameController.text = userName ?? '';
    _classController.text = userClass ?? '';

    if (url == null || url.isEmpty) {
      await _syncService.setWebAppUrl(defaultAppScriptUrl);
      _urlController.text = defaultAppScriptUrl;
    } else {
      _urlController.text = url;
    }

    _spreadsheetUrlController.text = spreadsheetUrl ?? '';

    setState(() {
      _autoSyncEnabled = autoSync;
      _lastSyncTime = lastSync?.toString();
      _totalLogs = total;
      _unsyncedLogs = unsynced;
      _isLoading = false;
    });
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      _showSnackBar('URL cannot be empty', isError: true);
      return;
    }

    if (!_isValidGoogleSheetsUrl(url)) {
      _showSnackBar(
        'Invalid Google Sheets Web App URL. Must start with https://script.google.com/',
        isError: true,
      );
      return;
    }

    await _syncService.setWebAppUrl(url);
    _showSnackBar('URL saved successfully');
  }

  bool _isValidGoogleSheetsUrl(String url) {
    return url.startsWith('https://script.google.com/') &&
        url.contains('/exec');
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      _showSnackBar('Please enter a URL first', isError: true);
      return;
    }

    if (!_isValidGoogleSheetsUrl(url)) {
      _showSnackBar('Invalid URL format', isError: true);
      return;
    }

    setState(() => _isTesting = true);

    // Save URL first
    await _syncService.setWebAppUrl(url);

    // Try to sync
    final success = await _syncService.syncLogs();

    setState(() => _isTesting = false);

    if (success) {
      _showSnackBar('Connection successful! ✓');
      _loadSettings(); // Reload to update stats
    } else {
      _showSnackBar(
        'Connection failed. Check URL and internet connection.',
        isError: true,
      );
    }
  }

  Future<void> _toggleAutoSync(bool value) async {
    await _syncService.setAutoSync(value);
    setState(() => _autoSyncEnabled = value);
    _showSnackBar(
      value ? 'Auto-sync enabled' : 'Auto-sync disabled',
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure you want to delete all scan logs? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.clearAllLogs();
      _showSnackBar('All data cleared');
      _loadSettings();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacingLarge),
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                          color: AppTheme.textDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Settings',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Sync Settings
                    _buildSection(
                      title: 'Sync Settings',
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _autoSyncEnabled,
                            onChanged: _toggleAutoSync,
                            title: const Text(
                              'Auto-sync',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            subtitle: const Text(
                              'Automatically sync after each scan',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            activeColor: AppTheme.primaryBlue,
                            contentPadding: EdgeInsets.zero,
                          ),

                          if (_lastSyncTime != null) ...[
                            const Divider(),
                            ListTile(
                              leading: const Icon(
                                Icons.sync,
                                color: AppTheme.successGreen,
                              ),
                              title: const Text(
                                'Last Sync',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              subtitle: Text(
                                _lastSyncTime!.substring(0, 19),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Data Statistics
                    _buildSection(
                      title: 'Data Statistics',
                      child: Column(
                        children: [
                          _buildStatRow('Total Logs', _totalLogs.toString()),
                          const Divider(),
                          _buildStatRow(
                              'Unsynced Logs', _unsyncedLogs.toString()),
                          const Divider(),
                          _buildStatRow(
                            'Synced Logs',
                            (_totalLogs - _unsyncedLogs).toString(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Danger Zone
                    _buildSection(
                      title: 'Danger Zone',
                      child: ListTile(
                        leading: const Icon(
                          Icons.delete_forever,
                          color: AppTheme.errorRed,
                        ),
                        title: const Text(
                          'Clear All Data',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.errorRed,
                          ),
                        ),
                        subtitle: const Text(
                          'Delete all scan logs permanently',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        onTap: _clearAllData,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingLarge),

                    // App Info
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'NFC Field Logger',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Watermark - positioned behind all content
            Positioned.fill(
              child: Center(
                child: Transform.rotate(
                  angle: -1.0, // Much more diagonal angle
                  child: _buildWatermark(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatermark() {
    return IgnorePointer(
      child: Container(
        child: Text(
          'FOR TESTING',
          style: TextStyle(
            fontSize: 48,
            color: Colors.grey.withOpacity(0.08),
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }



  @override
  void dispose() {
    _urlController.dispose();
    _spreadsheetUrlController.dispose();
    super.dispose();
  }
}
