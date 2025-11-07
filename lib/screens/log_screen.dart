import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scan_log.dart';
import 'settings_screen.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/export_service.dart';
import '../utils/app_theme.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({Key? key}) : super(key: key);

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();
  final ExportService _exportService = ExportService();

  List<ScanLog> _logs = [];
  List<ScanLog> _filteredLogs = [];
  int _totalScans = 0;
  String? _mostActiveCity;
  bool _isLoading = true;
  bool _showUnsyncedOnly = false;
  bool _isSyncing = false;
  bool _isExporting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final logs = await _dbHelper.getAllScanLogs();
      final totalScans = await _dbHelper.getTotalScanCount();
      final mostActiveCity = await _dbHelper.getMostActiveCity();

      setState(() {
        _logs = logs;
        _filteredLogs = logs;
        _totalScans = totalScans;
        _mostActiveCity = mostActiveCity;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<ScanLog> filtered = List.from(_logs);

    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      filtered = filtered
          .where((log) => log.uid
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
          .toList();
    }

    // Filter by sync status
    if (_showUnsyncedOnly) {
      filtered = filtered.where((log) => !log.isSynced).toList();
    }

    setState(() {
      _filteredLogs = filtered;
    });
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    
    final success = await _syncService.syncLogs();
    
    setState(() => _isSyncing = false);
    
    if (success) {
      _showSnackBar('Sync completed successfully');
      _loadData();
    } else {
      _showSnackBar('Sync failed', isError: true);
    }
  }

  Future<void> _exportCSV() async {
    setState(() => _isExporting = true);
    
    final filePath = await _exportService.exportToCSV();
    
    setState(() => _isExporting = false);
    
    if (filePath != null) {
      _showSnackBar('Exported to: $filePath');
    } else {
      _showSnackBar('Export failed', isError: true);
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

  void _showLogDetail(ScanLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('Scan Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('UID', log.uid, isMonospace: true),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildDetailRow(
              'Time',
              DateFormat('MMM dd, yyyy • HH:mm:ss').format(log.timestamp),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildDetailRow('City', log.city ?? 'Unknown'),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildDetailRow('Address', log.address ?? 'Unknown'),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildDetailRow('Coordinates', log.formattedCoordinates),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildDetailRow('Status', log.isSynced ? 'Synced' : 'Pending'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMonospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontFamily: isMonospace ? AppTheme.monoFontFamily : AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Log',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Online',
                                  style: TextStyle(
                                    color: AppTheme.successGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SettingsScreen(),
                                    ),
                                  ).then((_) => _loadData());
                                },
                                icon: const Icon(Icons.settings_outlined),
                                color: AppTheme.textDark,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTheme.spacingLarge),

                      // Stats cards
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingLarge),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactStatCard(
                                    Icons.download_outlined,
                                    'Total\nScans',
                                    _totalScans.toString(),
                                    AppTheme.primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingMedium),
                                Expanded(
                                  child: _buildCompactStatCard(
                                    Icons.schedule,
                                    '12:00 PM\nMost Active',
                                    _mostActiveCity ?? 'N/A',
                                    Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingMedium),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactStatCard(
                                    Icons.location_on_outlined,
                                    'New\nYork',
                                    '',
                                    AppTheme.successGreen.withOpacity(0.2),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingMedium),
                                Expanded(
                                  child: _buildCompactStatCard(
                                    Icons.sync,
                                    '2m ago\nLast Sync',
                                    '',
                                    AppTheme.primaryBlue.withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingLarge),

                      // Search bar
                      Container(
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
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search UID or location...',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppTheme.textSecondary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          onChanged: (value) => _applyFilters(),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingMedium),

                      // Filter chip
                      Row(
                        children: [
                          FilterChip(
                            label: Text(
                              'Show unsynced only',
                              style: TextStyle(
                                fontSize: 12,
                                color: _showUnsyncedOnly 
                                    ? AppTheme.primaryBlue 
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            selected: _showUnsyncedOnly,
                            onSelected: (selected) {
                              setState(() {
                                _showUnsyncedOnly = selected;
                              });
                              _applyFilters();
                            },
                            backgroundColor: Colors.white,
                            selectedColor: AppTheme.primaryBlue.withOpacity(0.1),
                            side: BorderSide(
                              color: _showUnsyncedOnly 
                                  ? AppTheme.primaryBlue 
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTheme.spacingMedium),

                      // Log list
                      Expanded(
                        child: _filteredLogs.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                itemCount: _filteredLogs.length,
                                itemBuilder: (context, index) {
                                  return _buildLogCard(_filteredLogs[index]);
                                },
                              ),
                      ),

                      const SizedBox(height: AppTheme.spacingMedium),

                      // Bottom actions
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _isExporting ? null : _exportCSV,
                                icon: _isExporting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.download_outlined),
                                label: Text(_isExporting ? 'Exporting...' : 'Export CSV'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppTheme.darkBackground,
                                  foregroundColor: Colors.white,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMedium),
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isSyncing ? null : _syncNow,
                                icon: _isSyncing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.sync_rounded),
                                label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCompactStatCard(
    IconData icon,
    String label,
    String value,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundColor == Colors.transparent
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: backgroundColor == AppTheme.successGreen.withOpacity(0.2)
                  ? AppTheme.successGreen
                  : backgroundColor == AppTheme.primaryBlue.withOpacity(0.1)
                      ? AppTheme.primaryBlue
                      : backgroundColor == AppTheme.primaryBlue
                          ? Colors.white
                          : AppTheme.textDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
                if (value.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(ScanLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
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
      child: InkWell(
        onTap: () => _showLogDetail(log),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  log.uid,
                  style: TextStyle(
                    fontFamily: AppTheme.monoFontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: log.isSynced 
                        ? AppTheme.successGreen.withOpacity(0.1) 
                        : AppTheme.warningOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    log.isSynced ? 'Synced' : 'Pending',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: log.isSynced 
                          ? AppTheme.successGreen 
                          : AppTheme.warningOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  DateFormat('MMM d, yyyy, h:mm a').format(log.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (log.city != null) ...[
                  Text(
                    ' • ',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      log.city!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 80,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            'No logs available',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            'Scan an NFC card to create a log entry',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
