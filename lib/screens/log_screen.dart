import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scan_log.dart';
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
    final success = await _syncService.syncLogs();
    if (success) {
      _showSnackBar('Sync completed successfully');
      _loadData();
    } else {
      _showSnackBar('Sync failed', isError: true);
    }
  }

  Future<void> _exportCSV() async {
    final filePath = await _exportService.exportToCSV();
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
      appBar: AppBar(
        title: const Text('Log'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Header stats
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Scans',
                            _totalScans.toString(),
                            Icons.grid_on,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMedium),
                        Expanded(
                          child: _buildStatCard(
                            'Most Active',
                            _mostActiveCity ?? 'N/A',
                            Icons.location_city,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Last sync time
                  if (_syncService.lastSyncTime != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
                      child: Text(
                        'Last sync: ${DateFormat('MMM dd • HH:mm').format(_syncService.lastSyncTime!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),

                  const SizedBox(height: AppTheme.spacingMedium),

                  // Filter bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search UID...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        _applyFilters();
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (value) => _applyFilters(),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSmall),
                        FilterChip(
                          label: const Text('Unsynced'),
                          selected: _showUnsyncedOnly,
                          onSelected: (selected) {
                            setState(() {
                              _showUnsyncedOnly = selected;
                            });
                            _applyFilters();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingMedium),

                  // Log list
                  Expanded(
                    child: _filteredLogs.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
                            itemCount: _filteredLogs.length,
                            itemBuilder: (context, index) {
                              return _buildLogCard(_filteredLogs[index]);
                            },
                          ),
                  ),

                  // Bottom actions
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _exportCSV,
                            icon: const Icon(Icons.file_download),
                            label: const Text('Export CSV'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: AppTheme.primaryBlue),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMedium),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _syncNow,
                            icon: const Icon(Icons.cloud_sync),
                            label: const Text('Sync Now'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppTheme.primaryBlue,
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

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryBlue, size: 28),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              value,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(ScanLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.spacingMedium),
        title: Text(
          log.uid,
          style: AppTheme.uidTextStyle.copyWith(fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTheme.spacingSmall),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, HH:mm').format(log.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (log.city != null) ...[
                  const SizedBox(width: AppTheme.spacingMedium),
                  Icon(Icons.location_on, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      log.city!,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            log.isSynced ? 'Synced' : 'Pending',
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: AppTheme.getStatusColor(log.isSynced ? 'synced' : 'pending'),
          padding: EdgeInsets.zero,
        ),
        onTap: () => _showLogDetail(log),
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
