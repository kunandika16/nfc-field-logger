import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../services/google_sheets_service.dart';
import '../services/database_helper.dart';
import '../utils/app_theme.dart';

class GoogleSheetsSetupScreen extends StatefulWidget {
  const GoogleSheetsSetupScreen({Key? key}) : super(key: key);

  @override
  State<GoogleSheetsSetupScreen> createState() =>
      _GoogleSheetsSetupScreenState();
}

class _GoogleSheetsSetupScreenState extends State<GoogleSheetsSetupScreen> {
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _spreadsheetNameController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSignedIn = false;
  bool _isCreating = false;
  bool _isSyncing = false;
  String? _userEmail;
  String? _savedSpreadsheetId;
  String? _savedSpreadsheetName;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    await _sheetsService.initialize();

    final user = _sheetsService.currentUser;
    final savedId = await _sheetsService.getSavedSpreadsheetId();
    final savedName = await _sheetsService.getSavedSpreadsheetName();

    setState(() {
      _isSignedIn = user != null;
      _userEmail = user?.email;
      _savedSpreadsheetId = savedId;
      _savedSpreadsheetName = savedName;
      _isLoading = false;
    });
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);

    final account = await _sheetsService.signIn();

    setState(() {
      _isSignedIn = account != null;
      _userEmail = account?.email;
      _isLoading = false;
    });

    if (account != null) {
      _showSnackBar('Signed in as ${account.email}');
    } else {
      _showSnackBar('Sign in failed', isError: true);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _sheetsService.signOut();
      await _sheetsService.clearSavedSpreadsheet();

      setState(() {
        _isSignedIn = false;
        _userEmail = null;
        _savedSpreadsheetId = null;
        _savedSpreadsheetName = null;
      });

      _showSnackBar('Signed out successfully');
    }
  }

  Future<void> _createSpreadsheet() async {
    final name = _spreadsheetNameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Please enter a spreadsheet name', isError: true);
      return;
    }

    setState(() => _isCreating = true);

    final result = await _sheetsService.createSpreadsheet(name);

    setState(() => _isCreating = false);

    if (result != null) {
      setState(() {
        _savedSpreadsheetId = result['id'];
        _savedSpreadsheetName = result['name'];
      });
      _spreadsheetNameController.clear();
      _showSnackBar('Spreadsheet created successfully!');
      Navigator.pop(context); // Close the dialog
    } else {
      _showSnackBar('Failed to create spreadsheet', isError: true);
    }
  }

  Future<void> _syncToSpreadsheet() async {
    if (_savedSpreadsheetId == null) {
      _showSnackBar('No spreadsheet configured', isError: true);
      return;
    }

    setState(() => _isSyncing = true);

    final logs = await _dbHelper.getUnsyncedLogs();

    if (logs.isEmpty) {
      setState(() => _isSyncing = false);
      _showSnackBar('No logs to sync');
      return;
    }

    final success = await _sheetsService.appendData(_savedSpreadsheetId!, logs);

    if (success) {
      // Mark as synced
      for (var log in logs) {
        if (log.id != null) {
          await _dbHelper.updateSyncStatus(log.id!, true);
        }
      }
      _showSnackBar('Synced ${logs.length} logs successfully!');
    } else {
      _showSnackBar('Sync failed', isError: true);
    }

    setState(() => _isSyncing = false);
  }

  Future<void> _openSpreadsheet() async {
    if (_savedSpreadsheetId == null) {
      _showSnackBar('Spreadsheet belum tersedia. Buat terlebih dahulu.',
          isError: true);
      return;
    }

    final url = _sheetsService.getSpreadsheetUrl(_savedSpreadsheetId!);
    final uri = Uri.parse(url);
    try {
      // 1) External app (Sheets/Browser)
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      // 2) In-app browser view
      final okInApp = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (okInApp) return;
      // 3) Default
      final okDefault = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (okDefault) return;

      // 4) Fallback: salin ke clipboard
      await Clipboard.setData(ClipboardData(text: url));
      _showSnackBar('Gagal membuka. Link disalin ke clipboard:\n$url',
          isError: true);
    } catch (e) {
      _showSnackBar('Error membuka spreadsheet: $e', isError: true);
    }
  }

  void _showCreateSpreadsheetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Spreadsheet'),
        content: TextField(
          controller: _spreadsheetNameController,
          decoration: const InputDecoration(
            labelText: 'Spreadsheet Name',
            hintText: 'NFC Scan Logs',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _isCreating ? null : _createSpreadsheet,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
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
                          'Google Sheets Setup',
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

                    const SizedBox(height: AppTheme.spacingLarge),

                    // Sign In Section
                    if (!_isSignedIn) ...[
                      _buildInfoCard(
                        icon: Icons.info_outline,
                        title: 'Easy Setup',
                        description:
                            'Sign in with Google to automatically create and manage your spreadsheet. No manual URL copying required!',
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(height: AppTheme.spacingMedium),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _signIn,
                          icon: Image.asset(
                            'assets/google_logo.png',
                            height: 24,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.login, color: Colors.white),
                          ),
                          label: const Text('Sign in with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // User Info
                      Container(
                        padding: const EdgeInsets.all(16),
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
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryBlue,
                              child: Text(
                                _userEmail?.substring(0, 1).toUpperCase() ??
                                    'U',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Signed in as',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _userEmail ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _signOut,
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingMedium),

                      // Spreadsheet Section
                      if (_savedSpreadsheetId == null) ...[
                        _buildInfoCard(
                          icon: Icons.add_circle_outline,
                          title: 'Create Spreadsheet',
                          description:
                              'Create a new Google Spreadsheet to store your NFC scan data.',
                          color: AppTheme.successGreen,
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showCreateSpreadsheetDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Create New Spreadsheet'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Active Spreadsheet
                        Container(
                          padding: const EdgeInsets.all(20),
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successGreen
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.table_chart,
                                      color: AppTheme.successGreen,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Active Spreadsheet',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _savedSpreadsheetName ??
                                              'Spreadsheet',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _openSpreadsheet,
                                      icon: const Icon(Icons.open_in_new,
                                          size: 18),
                                      label: const Text('Open'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryBlue,
                                        side: const BorderSide(
                                            color: AppTheme.primaryBlue),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isSyncing
                                          ? null
                                          : _syncToSpreadsheet,
                                      icon: _isSyncing
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.sync, size: 18),
                                      label: Text(_isSyncing
                                          ? 'Syncing...'
                                          : 'Sync Now'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.successGreen,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Change Spreadsheet'),
                                      content: const Text(
                                        'This will disconnect the current spreadsheet. You can create a new one or use a different account.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Continue'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await _sheetsService
                                        .clearSavedSpreadsheet();
                                    setState(() {
                                      _savedSpreadsheetId = null;
                                      _savedSpreadsheetName = null;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.swap_horiz, size: 18),
                                label: const Text('Change Spreadsheet'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _spreadsheetNameController.dispose();
    super.dispose();
  }
}
