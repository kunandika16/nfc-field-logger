import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../models/scan_log.dart';
import 'settings_screen.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/export_service.dart';
import '../utils/app_theme.dart';
import '../services/google_sheets_service.dart';
import '../utils/logger.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({Key? key}) : super(key: key);

  @override
  State<LogScreen> createState() => LogScreenState();
}

class LogScreenState extends State<LogScreen> {
  // Make loadData accessible from parent
  void refreshData() {
    _loadData();
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();
  final ExportService _exportService = ExportService();

  List<ScanLog> _logs = [];
  List<ScanLog> _filteredLogs = [];
  int _totalScans = 0;
  String? _mostActiveCity;
  DateTime? _lastSyncTime;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isExporting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadLastSyncTime();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadLastSyncTime() async {
    await _syncService.loadLastSyncTime();
    setState(() {
      _lastSyncTime = _syncService.lastSyncTime;
    });
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

      _applyFilters();
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
          .where((log) =>
              log.uid
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
              (log.city
                      ?.toLowerCase()
                      .contains(_searchController.text.toLowerCase()) ??
                  false) ||
              (log.address
                      ?.toLowerCase()
                      .contains(_searchController.text.toLowerCase()) ??
                  false) ||
              (log.userName
                      ?.toLowerCase()
                      .contains(_searchController.text.toLowerCase()) ??
                  false) ||
              (log.userClass
                      ?.toLowerCase()
                      .contains(_searchController.text.toLowerCase()) ??
                  false))
          .toList();
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
      await _loadLastSyncTime();
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
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: isSmallScreen ? 16 : 40,
        ),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: screenSize.height * (isSmallScreen ? 0.85 : 0.75),
            maxWidth: 400,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Info Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: 32,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    // Close Button
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        iconSize: 20,
                        color: AppTheme.textSecondary,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Subtitle
                      Text(
                        'Detail Scan',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Informasi lengkap dari log scan',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // UID Card (Primary)
                      _buildLogPrimaryCard(log),

                      const SizedBox(height: 16),

                      // User Info Section (if available)
                      if ((log.userName != null && log.userName!.isNotEmpty) ||
                          (log.userClass != null && log.userClass!.isNotEmpty))
                        _buildLogUserInfoSection(log),

                      const SizedBox(height: 16),

                      // Location & Time Section
                      _buildLogLocationTimeSection(log),

                      // Device Info (if available)
                      if (log.deviceInfo != null &&
                          log.deviceInfo!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildLogDeviceInfoSection(log),
                      ],

                      const SizedBox(height: 20),

                      // Sync Status
                      _buildLogSyncStatus(log),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Log Detail Methods
  Widget _buildLogPrimaryCard(ScanLog log) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withOpacity(0.1),
            AppTheme.primaryBlue.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.nfc,
                  size: 24,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NFC UID',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log.uid,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                        fontFamily: 'monospace',
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogUserInfoSection(ScanLog log) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi User',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          if (log.userName != null && log.userName!.isNotEmpty)
            _buildLogCompactDetailRow(
              icon: Icons.person_outline,
              label: 'Nama',
              value: log.userName!,
              iconColor: AppTheme.successGreen,
            ),
          if (log.userName != null &&
              log.userName!.isNotEmpty &&
              log.userClass != null &&
              log.userClass!.isNotEmpty)
            const SizedBox(height: 12),
          if (log.userClass != null && log.userClass!.isNotEmpty)
            _buildLogCompactDetailRow(
              icon: Icons.school_outlined,
              label: 'Kelas',
              value: log.userClass!,
              iconColor: AppTheme.successGreen,
            ),
        ],
      ),
    );
  }

  Widget _buildLogLocationTimeSection(ScanLog log) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lokasi & Waktu',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildLogCompactDetailRow(
            icon: Icons.access_time,
            label: 'Waktu',
            value: DateFormat('dd MMM yyyy, HH:mm').format(log.timestamp),
            iconColor: AppTheme.warningOrange,
          ),
          const SizedBox(height: 12),
          _buildLogCompactDetailRow(
            icon: Icons.location_city,
            label: 'Kota',
            value: (log.city == null || log.city!.isEmpty)
                ? 'Tidak diketahui'
                : log.city!,
            iconColor: AppTheme.warningOrange,
          ),
          const SizedBox(height: 12),
          _buildLogCompactDetailRow(
            icon: Icons.location_on,
            label: 'Alamat',
            value: (log.address == null || log.address!.isEmpty)
                ? 'Tidak diketahui'
                : log.address!,
            iconColor: AppTheme.warningOrange,
          ),
          if (log.latitude != null && log.longitude != null) ...[
            const SizedBox(height: 12),
            _buildLogCompactDetailRow(
              icon: Icons.my_location,
              label: 'Koordinat',
              value:
                  '${log.latitude!.toStringAsFixed(6)}, ${log.longitude!.toStringAsFixed(6)}',
              iconColor: AppTheme.warningOrange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogDeviceInfoSection(ScanLog log) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Perangkat',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildLogCompactDetailRow(
            icon: Icons.devices_other,
            label: 'Perangkat',
            value: log.deviceInfo!,
            iconColor: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildLogSyncStatus(ScanLog log) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: log.isSynced
            ? AppTheme.successGreen.withOpacity(0.1)
            : AppTheme.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: log.isSynced
              ? AppTheme.successGreen.withOpacity(0.3)
              : AppTheme.warningOrange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (log.isSynced
                      ? AppTheme.successGreen
                      : AppTheme.warningOrange)
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              log.isSynced ? Icons.cloud_done : Icons.cloud_queue,
              size: 20,
              color:
                  log.isSynced ? AppTheme.successGreen : AppTheme.warningOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Sinkronisasi',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.isSynced ? 'Tersinkronisasi' : 'Menunggu Sinkronisasi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: log.isSynced
                        ? AppTheme.successGreen
                        : AppTheme.warningOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCompactDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
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
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppTheme.textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _isExporting ? null : _exportCSV,
                                icon: _isExporting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.download_outlined),
                                color: AppTheme.textDark,
                                tooltip: 'Export CSV',
                              ),
                              IconButton(
                                onPressed: _isSyncing ? null : _syncNow,
                                icon: _isSyncing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.sync_rounded),
                                color: AppTheme.primaryBlue,
                                tooltip: 'Sync Now',
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SettingsScreen(),
                                    ),
                                  ).then((_) => _loadData());
                                },
                                icon: const Icon(Icons.settings_outlined),
                                color: AppTheme.textDark,
                                tooltip: 'Settings',
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTheme.spacingLarge),

                      // Stats cards
                      Column(
                        children: [
                          // Top 2 cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.qr_code_scanner,
                                  label: 'Total Scans',
                                  value: _totalScans.toString(),
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingMedium),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.location_city,
                                  label: 'Most Active',
                                  value: _mostActiveCity ?? 'N/A',
                                  color: AppTheme.successGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingMedium),
                          // Bottom wide card
                          _buildWideStatCard(
                            icon: Icons.sync,
                            label: 'Last Sync',
                            value: _lastSyncTime != null
                                ? _formatLastSync(_lastSyncTime!)
                                : 'Never',
                            subtitle: _lastSyncTime != null
                                ? DateFormat('MMM dd, yyyy • HH:mm')
                                    .format(_lastSyncTime!)
                                : 'No sync performed yet',
                            color: AppTheme.warningOrange,
                          ),
                        ],
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
                            hintText:
                                'Search UID, nama, kelas, atau location...',
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
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(lastSync);
    }
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 26,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
            // Name and Class row
            if (log.userName != null || log.userClass != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (log.userName != null) ...[
                      Icon(Icons.person, size: 14, color: AppTheme.primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        log.userName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (log.userName != null && log.userClass != null) ...[
                      Text(
                        ' • ',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (log.userClass != null) ...[
                      Icon(Icons.school,
                          size: 14, color: AppTheme.successGreen),
                      const SizedBox(width: 4),
                      Text(
                        log.userClass!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox,
            size: 60,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No logs available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan an NFC card to create a log entry',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
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
