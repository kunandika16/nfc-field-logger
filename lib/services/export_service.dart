import 'dart:io';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../models/scan_log.dart';
import 'database_helper.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Request storage permission
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isDenied) {
        // Try manageExternalStorage for Android 11+
        final manageStatus = await Permission.manageExternalStorage.request();
        return manageStatus.isGranted;
      }
      return status.isGranted;
    }
    return true; // iOS doesn't need explicit storage permission for app documents
  }

  // Export logs to CSV
  Future<String?> exportToCSV({
    DateTime? startDate,
    DateTime? endDate,
    bool unsyncedOnly = false,
  }) async {
    try {
      // Request permission
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      // Get logs
      List<ScanLog> logs;
      if (unsyncedOnly) {
        logs = await _dbHelper.getUnsyncedLogs();
      } else if (startDate != null && endDate != null) {
        logs = await _dbHelper.getLogsByDateRange(startDate, endDate);
      } else {
        logs = await _dbHelper.getAllScanLogs();
      }

      if (logs.isEmpty) {
        throw Exception('No logs to export');
      }

      // Prepare CSV data
      List<List<String>> csvData = [
        // Header row (extended)
        [
          'UID',
          'Name',
          'Class',
          'Device',
          'Brand',
          'Device Info',
          'Timestamp',
          'Latitude',
          'Longitude',
          'Address',
          'City',
          'Synced',
          'Status'
        ],
        // Data rows
        ...logs.map((log) => log.toCsvRow()),
      ];

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(csvData);

      // Create filename with timestamp (YYYY-MM-DD_HH-mm-ss)
      final now = DateTime.now();
      final timestamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
      final filename = 'nfc_logs_$timestamp.csv';

      // Let user pick directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        // User cancelled
        return null;
      }

      final filePath = '$selectedDirectory/$filename';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(csv);

      return filePath;
    } catch (e) {
      return null;
    }
  }

  // Export specific logs to CSV
  Future<String?> exportSpecificLogs(List<ScanLog> logs) async {
    try {
      if (logs.isEmpty) {
        throw Exception('No logs to export');
      }

      // Request permission
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      // Prepare CSV data
      List<List<String>> csvData = [
        // Header row (extended)
        [
          'UID',
          'Name',
          'Class',
          'Device',
          'Brand',
          'Device Info',
          'Timestamp',
          'Latitude',
          'Longitude',
          'Address',
          'City',
          'Synced',
          'Status'
        ],
        // Data rows
        ...logs.map((log) => log.toCsvRow()),
      ];

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(csvData);

      // Create filename (YYYY-MM-DD_HH-mm-ss)
      final now = DateTime.now();
      final timestamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
      final filename = 'nfc_logs_$timestamp.csv';

      // Let user pick directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        // User cancelled
        return null;
      }

      final filePath = '$selectedDirectory/$filename';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(csv);

      return filePath;
    } catch (e) {
      return null;
    }
  }

  // Get export statistics
  Future<Map<String, int>> getExportStats() async {
    final totalLogs = await _dbHelper.getTotalScanCount();
    final unsyncedLogs = await _dbHelper.getUnsyncedLogs();

    return {
      'total': totalLogs,
      'unsynced': unsyncedLogs.length,
      'synced': totalLogs - unsyncedLogs.length,
    };
  }
}
