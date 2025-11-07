import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scan_log.dart';
import '../services/nfc_service.dart';
import '../services/location_service.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../utils/app_theme.dart';

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
  ScanLog? _lastScan;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeNfc();
    _initializeAnimation();
    _syncService.initialize();
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
    if (!_nfcAvailable) {
      _showSnackBar('NFC is not available on this device', isError: true);
      return;
    }

    setState(() {
      _isScanning = true;
    });

    _animationController.repeat(reverse: true);

    try {
      // Scan NFC tag
      final uid = await _nfcService.scanNfcTag();

      if (uid == null) {
        _showSnackBar('No UID found on NFC tag', isError: true);
        _stopScanning();
        return;
      }

      // Get location data
      final locationData = await _locationService.getCompleteLocationData();

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

      // Save to database
      await _dbHelper.insertScanLog(scanLog);

      // Update UI
      setState(() {
        _lastScan = scanLog;
      });

      _showSnackBar('Saved to log successfully');

      // Auto-sync if online
      _syncService.autoSync();
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
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

  String _getSyncStatusText() {
    switch (_syncService.status) {
      case SyncStatus.online:
        return 'Online';
      case SyncStatus.offline:
        return 'Offline';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.error:
        return 'Error';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Chip(
              label: Text(_getSyncStatusText()),
              avatar: Icon(
                Icons.circle,
                size: 12,
                color: AppTheme.getStatusColor(_getSyncStatusText()),
              ),
              backgroundColor: AppTheme.cardBackground,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Offline banner
              if (_syncService.status == SyncStatus.offline)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingLarge),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.warningOrange),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: AppTheme.warningOrange),
                      const SizedBox(width: AppTheme.spacingMedium),
                      Expanded(
                        child: Text(
                          'Offline mode – data will auto-sync when online',
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

              // Main scan card
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLarge),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // NFC Icon with animation
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isScanning ? _scaleAnimation.value : 1.0,
                              child: Icon(
                                Icons.nfc,
                                size: 120,
                                color: _isScanning 
                                    ? AppTheme.primaryBlue 
                                    : AppTheme.textSecondary,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: AppTheme.spacingLarge),

                        // Scan result or instruction
                        if (_lastScan != null) ...[
                          Text(
                            'Last Scan Result',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppTheme.spacingMedium),
                          
                          // UID
                          Text(
                            _lastScan!.uid,
                            style: AppTheme.uidTextStyle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spacingMedium),

                          // Timestamp
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.access_time, size: 18, color: AppTheme.textSecondary),
                              const SizedBox(width: AppTheme.spacingSmall),
                              Text(
                                DateFormat('MMM dd, yyyy • HH:mm:ss').format(_lastScan!.timestamp),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingSmall),

                          // Location
                          if (_lastScan!.city != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on, size: 18, color: AppTheme.textSecondary),
                                const SizedBox(width: AppTheme.spacingSmall),
                                Text(
                                  _lastScan!.city!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          const SizedBox(height: AppTheme.spacingSmall),

                          // Coordinates
                          if (_lastScan!.latitude != null && _lastScan!.longitude != null)
                            Text(
                              _lastScan!.formattedCoordinates,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ] else ...[
                          Text(
                            _isScanning ? 'Hold your device near an NFC card' : 'Tap the button below to scan',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? null : _startScan,
        icon: Icon(_isScanning ? Icons.stop : Icons.nfc),
        label: Text(_isScanning ? 'Scanning...' : 'Scan NFC'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
