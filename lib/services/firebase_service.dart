import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/scan_log.dart';
import '../utils/logger.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  late FirebaseDatabase _database;
  late FirebaseAuth _auth;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  // Initialize Firebase
  Future<bool> initialize() async {
    try {
      if (_initialized) {
        AppLogger.info('Firebase already initialized');
        return true;
      }

      AppLogger.info('Starting Firebase initialization...');
      
      // Initialize Firebase
      await Firebase.initializeApp();
      AppLogger.info('Firebase.initializeApp() completed');
      
      _database = FirebaseDatabase.instance;
      AppLogger.info('FirebaseDatabase instance obtained');
      
      _auth = FirebaseAuth.instance;
      AppLogger.info('FirebaseAuth instance obtained');
      
      // Try to enable offline persistence
      try {
        _database.setPersistenceEnabled(true);
        AppLogger.info('Offline persistence enabled');
      } catch (e) {
        AppLogger.warning('Could not enable offline persistence: $e');
      }
      
      // Try anonymous sign-in
      try {
        if (_auth.currentUser == null) {
          await _auth.signInAnonymously();
          AppLogger.info('Anonymous sign-in successful, uid: ${_auth.currentUser?.uid}');
        } else {
          AppLogger.info('User already signed in: ${_auth.currentUser?.uid}');
        }
      } catch (e) {
        AppLogger.warning('Anonymous sign-in failed (may be expected): $e');
      }
      
      _initialized = true;
      AppLogger.info('✅ Firebase initialized successfully');
      return true;
    } catch (e) {
      AppLogger.warning('⚠️ Firebase initialization warning: $e');
      // Don't fail completely - app can still work with local database
      _initialized = false;
      return false;
    }
  }

  // Anonymous sign in
  Future<bool> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
      AppLogger.info('Anonymous sign in successful');
      return true;
    } catch (e) {
      AppLogger.error('Anonymous sign in failed', e);
      return false;
    }
  }

  // Get or create user ID
  Future<String> getUserId() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        await signInAnonymously();
        user = _auth.currentUser;
      }
      return user?.uid ?? 'unknown';
    } catch (e) {
      AppLogger.error('Error getting user ID', e);
      return 'unknown';
    }
  }

  // Sync logs to Firebase
  Future<bool> syncLogs(List<ScanLog> logs) async {
    try {
      if (!_initialized) {
        AppLogger.warning('Firebase not initialized');
        return false;
      }

      if (logs.isEmpty) {
        AppLogger.info('No logs to sync');
        return true;
      }

      String userId = await getUserId();
      final ref = _database.ref('users/$userId/logs');

      // Convert logs to map
      Map<String, dynamic> logsData = {};
      for (var log in logs) {
        String logKey = '${log.uid}_${log.timestamp.millisecondsSinceEpoch}';
        logsData[logKey] = {
          'uid': log.uid,
          'timestamp': log.timestamp.toIso8601String(),
          'latitude': log.latitude,
          'longitude': log.longitude,
          'address': log.address,
          'city': log.city,
          'isSynced': true,
        };
      }

      // Upload to Firebase
      await ref.update(logsData);
      AppLogger.info('Successfully synced ${logs.length} logs to Firebase');
      return true;
    } catch (e) {
      AppLogger.error('Error syncing logs to Firebase', e);
      return false;
    }
  }

  // Get all logs from Firebase
  Future<List<Map<String, dynamic>>> getAllLogsFromFirebase() async {
    try {
      String userId = await getUserId();
      final ref = _database.ref('users/$userId/logs');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        AppLogger.info('No logs found in Firebase');
        return [];
      }

      List<Map<String, dynamic>> logsList = [];
      Map<dynamic, dynamic> logsMap = snapshot.value as Map<dynamic, dynamic>;

      logsMap.forEach((key, value) {
        logsList.add({
          'key': key,
          ...Map<String, dynamic>.from(value as Map),
        });
      });

      AppLogger.info('Retrieved ${logsList.length} logs from Firebase');
      return logsList;
    } catch (e) {
      AppLogger.error('Error getting logs from Firebase', e);
      return [];
    }
  }

  // Export to Google Sheets (simple CSV via Firebase)
  Future<bool> exportToGoogleSheets(List<ScanLog> logs) async {
    try {
      if (!_initialized) {
        AppLogger.warning('Firebase not initialized');
        return false;
      }

      String userId = await getUserId();
      final ref = _database.ref('users/$userId/exports');

      // Create export record
      final exportData = {
        'timestamp': DateTime.now().toIso8601String(),
        'logsCount': logs.length,
        'logs': logs.map((log) => {
          'uid': log.uid,
          'timestamp': log.timestamp.toIso8601String(),
          'latitude': log.latitude,
          'longitude': log.longitude,
          'address': log.address,
          'city': log.city,
        }).toList(),
        'status': 'ready_for_export'
      };

      await ref.push().set(exportData);
      AppLogger.info('Export record created in Firebase');
      return true;
    } catch (e) {
      AppLogger.error('Error creating export record', e);
      return false;
    }
  }

  // Get Firebase URL for user data
  Future<String?> getFirebaseDataUrl() async {
    try {
      String userId = await getUserId();
      return 'https://console.firebase.google.com/project/YOUR_PROJECT_ID/database/data/users/$userId';
    } catch (e) {
      AppLogger.error('Error getting Firebase URL', e);
      return null;
    }
  }

  // Clear all synced logs from Firebase
  Future<bool> clearFirebaseData() async {
    try {
      String userId = await getUserId();
      final ref = _database.ref('users/$userId');
      await ref.remove();
      AppLogger.info('Firebase data cleared');
      return true;
    } catch (e) {
      AppLogger.error('Error clearing Firebase data', e);
      return false;
    }
  }
}
