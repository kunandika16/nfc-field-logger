import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_log.dart';
import 'database_helper.dart';
import '../utils/logger.dart';

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

  // Keys for SharedPreferences
  static const String _webAppUrlKey = 'google_sheets_web_app_url';
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

  // Get Google Sheets Web App URL
  Future<String?> getWebAppUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_webAppUrlKey);
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

      // Get Web App URL
      final webAppUrl = await getWebAppUrl();
      if (webAppUrl == null || webAppUrl.isEmpty) {
        AppLogger.warning('Google Sheets Web App URL not configured');
        _updateStatus(SyncStatus.error);
        return false;
      }

      // Get unsynced logs
      List<ScanLog> unsyncedLogs = await _dbHelper.getUnsyncedLogs();
      if (unsyncedLogs.isEmpty) {
        _updateStatus(SyncStatus.online);
        await _saveLastSyncTime();
        return true;
      }

      // Prepare data for Google Sheets
      List<Map<String, dynamic>> dataToSync = unsyncedLogs.map((log) {
        return {
          'uid': log.uid,
          'timestamp': log.timestamp.toIso8601String(),
          'latitude': log.latitude?.toString() ?? '',
          'longitude': log.longitude?.toString() ?? '',
          'address': log.address ?? '',
          'city': log.city ?? '',
        };
      }).toList();

      // Send to Google Sheets via Web App
      final response = await http.post(
        Uri.parse(webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'logs': dataToSync}),
      );

      if (response.statusCode == 200) {
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
        AppLogger.error('Sync failed with status: ${response.statusCode}');
        _updateStatus(SyncStatus.error);
        return false;
      }
    } catch (e) {
      AppLogger.error('Error syncing', e);
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
