import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/database_helper.dart';
import '../models/scan_log.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SyncService _syncService = SyncService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _urlController = TextEditingController();
  
  // Default Google Apps Script URL
  static const String defaultAppScriptUrl =
      'https://script.google.com/macros/s/AKfycbzeTOW-Wc9Cam1BunoX8A2kRIo871p7T3DZT6x9EQRm3veJnjd6Ztii3tkV1AIjnii80w/exec';
  
  bool _isLoading = true;
  bool _isTesting = false;
  bool _isEditingUrl = false;
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
    final autoSync = await _syncService.isAutoSyncEnabled();
    final lastSync = _syncService.lastSyncTime;
    final total = await _dbHelper.getTotalScanCount();
    final unsynced = await _dbHelper.getUnsyncedCount();

    // If no URL is set, use default URL
    if (url == null || url.isEmpty) {
      await _syncService.setWebAppUrl(defaultAppScriptUrl);
      _urlController.text = defaultAppScriptUrl;
    } else {
      _urlController.text = url;
    }

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

  Future<void> _addDummyData() async {
    try {
      // Generate random location data for variety
      final random = DateTime.now().millisecondsSinceEpoch % 3;
      
      final List<Map<String, dynamic>> dummyLocations = [
        {
          'city': 'Bandung',
          'address': 'Jl. Asia Afrika No.8, Bandung, Jawa Barat',
          'lat': -6.914744,
          'lng': 107.609810,
        },
        {
          'city': 'Jakarta',
          'address': 'Jl. Thamrin No.1, Jakarta Pusat, DKI Jakarta',
          'lat': -6.200000,
          'lng': 106.816666,
        },
        {
          'city': 'Surabaya',
          'address': 'Jl. Pemuda No.31, Surabaya, Jawa Timur',
          'lat': -7.250445,
          'lng': 112.768845,
        },
      ];
      
      final location = dummyLocations[random];
      
      // Generate random UID
      final now = DateTime.now();
      final uid = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}:${now.millisecond.toString().padLeft(3, '0').substring(0, 2)}';
      
      await _dbHelper.insertScanLog(
        ScanLog(
          uid: uid,
          timestamp: now,
          latitude: location['lat'] as double,
          longitude: location['lng'] as double,
          address: location['address'] as String,
          city: location['city'] as String,
          isSynced: false,
        ),
      );
      
      _showSnackBar('Dummy data added: ${location['city']}');
      _loadSettings();
    } catch (e) {
      _showSnackBar('Error adding dummy data', isError: true);
    }
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
        child: _isLoading
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
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingLarge),

                    // Google Sheets Configuration
                    _buildSection(
                      title: 'Google Sheets Integration',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Web App URL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isEditingUrl = !_isEditingUrl;
                                  });
                                },
                                icon: Icon(
                                  _isEditingUrl ? Icons.close : Icons.edit,
                                  size: 16,
                                ),
                                label: Text(_isEditingUrl ? 'Cancel' : 'Edit'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isEditingUrl)
                            TextField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                hintText: 'https://script.google.com/macros/s/.../exec',
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                filled: true,
                                fillColor: AppTheme.lightBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              maxLines: 3,
                              style: const TextStyle(fontSize: 12),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.lightBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.link,
                                    size: 20,
                                    color: AppTheme.successGreen,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _urlController.text.isNotEmpty
                                          ? _urlController.text
                                          : 'No URL configured',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (_isEditingUrl)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _saveUrl();
                                      setState(() => _isEditingUrl = false);
                                    },
                                    icon: const Icon(Icons.save_outlined, size: 18),
                                    label: const Text('Save URL'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryBlue,
                                      side: const BorderSide(color: AppTheme.primaryBlue),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isTesting ? null : _testConnection,
                                    icon: _isTesting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.wifi_find, size: 18),
                                    label: Text(_isTesting ? 'Testing...' : 'Test'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isTesting ? null : _testConnection,
                                icon: _isTesting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.wifi_find, size: 18),
                                label: Text(_isTesting ? 'Testing Connection...' : 'Test Connection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Deploy a Google Apps Script as Web App and paste the URL here.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                          _buildStatRow('Unsynced Logs', _unsyncedLogs.toString()),
                          const Divider(),
                          _buildStatRow(
                            'Synced Logs',
                            (_totalLogs - _unsyncedLogs).toString(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Testing Tools
                    _buildSection(
                      title: 'Testing Tools',
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add_circle_outline,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            title: const Text(
                              'Add Dummy Data',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            subtitle: const Text(
                              'Add test scan log for emulator testing',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            onTap: _addDummyData,
                            contentPadding: EdgeInsets.zero,
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
    super.dispose();
  }
}
