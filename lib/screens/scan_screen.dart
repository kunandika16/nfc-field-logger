import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/scan_log.dart';
import '../services/nfc_service.dart';
import 'settings_screen.dart';
import '../services/location_service.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../utils/app_theme.dart';
import '../widgets/nfc_success_dialog.dart';
import '../widgets/nfc_error_dialog.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final NfcService _nfcService = NfcService();
  final LocationService _locationService = LocationService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();

  bool _isScanning = false;
  bool _nfcAvailable = false;
  bool _isOnline = false;
  ScanLog? _lastScan;
  int _totalScans = 0;
  int _unsyncedCount = 0;
  int _syncedCount = 0;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeNfc();
    _initializeAnimation();
    _syncService.initialize();
    _loadStats();
    _checkConnectivity();
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  Future<void> _loadStats() async {
    final total = await _dbHelper.getTotalScanCount();
    final unsynced = await _dbHelper.getUnsyncedCount();
    setState(() {
      _totalScans = total;
      _unsyncedCount = unsynced;
      _syncedCount = total - unsynced;
    });
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeNfc() async {
    final available = await _nfcService.checkAvailability();
    setState(() {
      _nfcAvailable = available;
    });
  }

  Future<void> _startScan() async {
    print('Starting NFC scan...');
    
    if (!_nfcAvailable) {
      print('NFC not available');
      _showSnackBar('NFC is not available on this device', isError: true);
      return;
    }

    if (_nfcService.isScanning) {
      print('NFC scan already in progress');
      _showSnackBar('Scan already in progress', isError: true);
      return;
    }

    setState(() {
      _isScanning = true;
    });

    _animationController.repeat(reverse: true);
    _showSnackBar('Hold your device near an NFC card...');

    try {
      print('Calling NFC service scanNfcTag...');
      // Scan NFC tag
      final uid = await _nfcService.scanNfcTag();
      print('NFC scan result: $uid');

      if (uid == null || uid.isEmpty) {
        print('No UID found');
        _showSnackBar('No UID found on NFC tag', isError: true);
        _stopScanning();
        return;
      }

      print('Getting location data...');
      // Get location data
      final locationData = await _locationService.getCompleteLocationData();
      print('Location data: ${locationData?.toString()}');

      // Create scan log
      final scanLog = ScanLog(
        uid: uid,
        timestamp: DateTime.now(),
        latitude: locationData?.latitude,
        longitude: locationData?.longitude,
        address: locationData?.address,
        city: locationData?.city,
        isSynced: false,
      );

      print('Saving to database...');
      // Save to database
      await _dbHelper.insertScanLog(scanLog);
      print('Saved successfully');

      // Update UI
      setState(() {
        _lastScan = scanLog;
      });

      // Reload stats
      await _loadStats();
      print('Stats reloaded after scan');

      // Show success dialog
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => NfcSuccessDialog(
            scanLog: scanLog,
            onClose: () {
              Navigator.of(context).pop();
            },
          ),
        );
      }

      // Auto-sync if online
      _syncService.autoSync();
    } catch (e) {
      print('NFC scan error: $e');
      
      // Show error dialog for timeout
      if (mounted && e.toString().contains('timeout')) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => NfcErrorDialog(
            title: 'Scan Failed',
            message: 'No NFC tag detected within 10 seconds. Please make sure the NFC tag is close to your device and try again.',
            onClose: () {},
            onRetry: _startScan,
          ),
        );
      } else {
        _showSnackBar('Error: ${e.toString()}', isError: true);
      }
    } finally {
      _stopScanning();
    }
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
    });
    _animationController.stop();
    _animationController.reset();
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


  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
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
                    'Scan',
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
                          color: (_isOnline ? AppTheme.successGreen : AppTheme.errorRed).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isOnline ? AppTheme.successGreen : AppTheme.errorRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: _isOnline ? AppTheme.successGreen : AppTheme.errorRed,
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
                          ).then((_) => _loadStats());
                        },
                        icon: const Icon(Icons.settings_outlined),
                        color: AppTheme.textDark,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingLarge),

              // Main scan card
              Expanded(
                child: Container(
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
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingLarge * 2,
                        vertical: AppTheme.spacingLarge,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // NFC Icon with animation and background
                          AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _isScanning ? _scaleAnimation.value : 1.0,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.contactless,
                                      size: 70,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: AppTheme.spacingLarge * 1.5),

                          // Instruction text
                          Text(
                            _isScanning 
                                ? 'Hold your device near an NFC card' 
                                : 'Tap the button below to scan\nan NFC card',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.textDark,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingLarge),

              // Scan button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: AppTheme.primaryBlue.withOpacity(0.5),
                  ),
                  child: Text(
                    _isScanning ? 'Scanning...' : 'Scan NFC',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMedium),

              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(_totalScans.toString(), 'Total scans'),
                  ),
                  const SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: _buildStatItem(_unsyncedCount.toString(), 'Unsynced'),
                  ),
                  const SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: _buildStatItem(_syncedCount.toString(), 'Synced'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
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
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
