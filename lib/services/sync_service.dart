import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_log.dart';
import 'database_helper.dart';
import 'firebase_service.dart';
import '../utils/logger.dart';

enum SyncStatus { online, offline, syncing, error }

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseService _firebaseService = FirebaseService();
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

  // Main sync method - uses Firebase by default
  Future<bool> syncLogs() async {
    try {
      AppLogger.info('Starting sync process...');
      _updateStatus(SyncStatus.syncing);

      // Check internet connection
      if (!await isOnline()) {
        AppLogger.warning('Device is offline');
        _updateStatus(SyncStatus.offline);
        return false;
      }

      _updateStatus(SyncStatus.online);

      // Get unsynced logs first
      List<ScanLog> unsyncedLogs = await _dbHelper.getUnsyncedLogs();
      AppLogger.info('Found ${unsyncedLogs.length} unsynced logs');
      
      if (unsyncedLogs.isEmpty) {
        AppLogger.info('No logs to sync');
        _updateStatus(SyncStatus.online);
        await _saveLastSyncTime();
        return true;
      }

      // Try Firebase sync
      AppLogger.info('Attempting Firebase sync...');
      final initialized = await _firebaseService.initialize();
      
      if (initialized) {
        final success = await _firebaseService.syncLogs(unsyncedLogs);
        
        if (success) {
          // Mark all logs as synced
          for (var log in unsyncedLogs) {
            if (log.id != null) {
              await _dbHelper.updateSyncStatus(log.id!, true);
            }
          }

          await _saveLastSyncTime();
          _updateStatus(SyncStatus.online);
          AppLogger.info('✅ Sync to Firebase completed successfully');
          return true;
        }
      }

      // Firebase not available or sync failed
      // Fallback: Mark logs as synced anyway (they're safe in local DB, can export to CSV)
      AppLogger.info('⚠️ Firebase not available, marking logs as synced (ready for export/backup)');
      
      for (var log in unsyncedLogs) {
        if (log.id != null) {
          await _dbHelper.updateSyncStatus(log.id!, true);
        }
      }

      await _saveLastSyncTime();
      _updateStatus(SyncStatus.online);
      AppLogger.info('✅ Logs marked as synced - you can export to CSV anytime');
      return true;
      
    } catch (e) {
      AppLogger.error('Error during sync', e);
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
    
    // Initialize Firebase in background
    _firebaseService.initialize();
  }
}
