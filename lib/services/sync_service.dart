import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_log.dart';
import 'database_helper.dart';
import 'google_sheets_service.dart';

enum SyncStatus { online, offline, syncing, error }

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  SyncStatus _status = SyncStatus.offline;
  DateTime? _lastSyncTime;

  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Hardcoded Apps Script Web App URL
  static const String _hardcodedWebAppUrl =
      'https://script.google.com/macros/s/AKfycbyQa3lLY_p6ApbwbJRqfPW0ABHSO8S70uu_E9OwEqpKRDOfS89H1x-M7Wtq8ENX8jeraQ/exec';

  // Keys for SharedPreferences
  static const String _webAppUrlKey = 'google_sheets_web_app_url';
  static const String _spreadsheetUrlKey = 'google_spreadsheet_url';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _autoSyncKey = 'auto_sync_enabled';

  // Check if device is online
  Future<bool> isOnline() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Set Google Sheets Web App URL
  Future<void> setWebAppUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webAppUrlKey, url);
  }

  // Get Google Sheets Web App URL (now hardcoded)
  Future<String?> getWebAppUrl() async {
    return _hardcodedWebAppUrl;
  }

  // Set Google Spreadsheet URL for viewing
  Future<void> setSpreadsheetUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spreadsheetUrlKey, url);
  }

  // Get Google Spreadsheet URL
  Future<String?> getSpreadsheetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_spreadsheetUrlKey);
  }

  // Enable/disable auto-sync
  Future<void> setAutoSync(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, enabled);
  }

  // Check if auto-sync is enabled
  Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? true;
  }

  // Load last sync time from storage
  Future<void> loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastSyncKey);
    if (timestamp != null) {
      _lastSyncTime = DateTime.parse(timestamp);
    }
  }

  // Update status
  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
  }

  // Sync unsynced logs to Google Sheets
  Future<bool> syncLogs() async {
    try {
      _updateStatus(SyncStatus.syncing);

      // Check internet connection
      if (!await isOnline()) {
        _updateStatus(SyncStatus.offline);
        return false;
      }

      _updateStatus(SyncStatus.online);

      // Get unsynced logs
      List<ScanLog> unsyncedLogs = await _dbHelper.getUnsyncedLogs();

      if (unsyncedLogs.isEmpty) {
        _updateStatus(SyncStatus.online);
        await _saveLastSyncTime();
        return true;
      }

      // PRIORITY 1: Try Easy Setup (Google Sheets API) if configured
      final sheetsService = GoogleSheetsService();
      final spreadsheetId = await sheetsService.getSavedSpreadsheetId();
      
      if (spreadsheetId != null && spreadsheetId.isNotEmpty) {
        final success =
            await sheetsService.appendData(spreadsheetId, unsyncedLogs);

        if (success) {
          // Mark all logs as synced
          for (var log in unsyncedLogs) {
            if (log.id != null) {
              await _dbHelper.updateSyncStatus(log.id!, true);
            }
          }
          await _saveLastSyncTime();
          _updateStatus(SyncStatus.online);
          return true;
        }
      }

      // PRIORITY 2: Fallback to Apps Script URL (manual setup)
      final webAppUrl = await getWebAppUrl();

      if (webAppUrl == null || webAppUrl.isEmpty) {
        _updateStatus(SyncStatus.error);
        return false;
      }

      // Prepare data for Google Sheets with formatted timestamp
      List<Map<String, dynamic>> dataToSync = unsyncedLogs.map((log) {
        // Format timestamp to readable format: "2025-11-15 17:30:45"
        final formattedTimestamp =
            '${log.timestamp.year}-${log.timestamp.month.toString().padLeft(2, '0')}-${log.timestamp.day.toString().padLeft(2, '0')} ' +
                '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';

        return {
          'uid': log.uid,
          'timestamp': formattedTimestamp,
          'latitude': log.latitude,
          'longitude': log.longitude,
          'address': log.address ?? '',
          'city': log.city ?? '',
          'user_name': log.userName ?? '',
          'user_class': log.userClass ?? '',
          'device_info': log.deviceInfo ?? '',
        };
      }).toList();

      final requestBody = jsonEncode({'logs': dataToSync});

      // Send to Google Sheets via Web App
      final response = await http
          .post(
        Uri.parse(webAppUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );

      // Google Apps Script returns 302 redirect after successful execution
      // This is normal behavior - the data has already been saved
      if (response.statusCode == 302 || response.statusCode == 301) {
        // Mark all logs as synced
        for (var log in unsyncedLogs) {
          if (log.id != null) {
            await _dbHelper.updateSyncStatus(log.id!, true);
          }
        }

        await _saveLastSyncTime();
        _updateStatus(SyncStatus.online);
        return true;
      }

      if (response.statusCode == 200) {
        // Try to parse response
        try {
          final responseData = jsonDecode(response.body);

          if (responseData['status'] == 'success') {
            // Mark all logs as synced
            for (var log in unsyncedLogs) {
              if (log.id != null) {
                await _dbHelper.updateSyncStatus(log.id!, true);
              }
            }

            await _saveLastSyncTime();
            _updateStatus(SyncStatus.online);
            return true;
          } else {
            _updateStatus(SyncStatus.error);
            return false;
          }
        } catch (e) {
          _updateStatus(SyncStatus.error);
          return false;
        }
      } else {
        _updateStatus(SyncStatus.error);
        return false;
      }
    } catch (e) {
      _updateStatus(SyncStatus.error);
      return false;
    }
  }

  // Auto-sync if enabled and online
  Future<void> autoSync() async {
    if (await isAutoSyncEnabled()) {
      await syncLogs();
    }
  }

  // Save last sync time
  Future<void> _saveLastSyncTime() async {
    _lastSyncTime = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
  }

  // Monitor connectivity changes
  Stream<SyncStatus> monitorConnectivity() {
    return Connectivity().onConnectivityChanged.asyncMap((result) async {
      if (result == ConnectivityResult.none) {
        _updateStatus(SyncStatus.offline);
        return SyncStatus.offline;
      } else {
        _updateStatus(SyncStatus.online);
        // Attempt auto-sync when connection is restored
        await autoSync();
        return _status;
      }
    });
  }

  // Initialize sync service
  Future<void> initialize() async {
    await loadLastSyncTime();
    final online = await isOnline();
    _updateStatus(online ? SyncStatus.online : SyncStatus.offline);
  }
}
