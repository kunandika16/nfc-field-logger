import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/scan_log.dart';
import 'database_helper.dart';
import '../utils/logger.dart';

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
        // Header row
        ['UID', 'Timestamp', 'Latitude', 'Longitude', 'Address', 'City', 'Synced'],
        // Data rows
        ...logs.map((log) => log.toCsvRow()),
      ];

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(csvData);

      // Get directory to save file
      Directory? directory;
      if (Platform.isAndroid) {
        // Try to get Downloads directory for Android
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'nfc_logs_$timestamp.csv';
      final filePath = '${directory.path}/$filename';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(csv);

      return filePath;
    } catch (e) {
      AppLogger.error('Error exporting CSV', e);
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
        // Header row
        ['UID', 'Timestamp', 'Latitude', 'Longitude', 'Address', 'City', 'Synced'],
        // Data rows
        ...logs.map((log) => log.toCsvRow()),
      ];

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(csvData);

      // Get directory to save file
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create filename
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'nfc_logs_$timestamp.csv';
      final filePath = '${directory.path}/$filename';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(csv);

      return filePath;
    } catch (e) {
      AppLogger.error('Error exporting specific logs', e);
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
