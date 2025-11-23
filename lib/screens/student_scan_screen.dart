import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/scan_log.dart';
import '../services/nfc_service.dart';
import '../services/location_service.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/feedback_service.dart';
import '../utils/app_theme.dart';
import '../widgets/nfc_success_dialog.dart';
import '../services/device_info_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/nfc_error_dialog.dart';
import '../utils/logger.dart';
import 'role_selection_screen.dart';

class StudentScanScreen extends StatefulWidget {
  const StudentScanScreen({Key? key}) : super(key: key);

  @override
  State<StudentScanScreen> createState() => _StudentScanScreenState();
}

class _StudentScanScreenState extends State<StudentScanScreen>
    with SingleTickerProviderStateMixin {
  final NfcService _nfcService = NfcService();
  final LocationService _locationService = LocationService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();
  final FeedbackService _feedbackService = FeedbackService();

  bool _isScanning = false;
  bool _nfcAvailable = false;
  bool _isOnline = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeNfc();
    _initializeAnimation();
    _syncService.initialize();
    _feedbackService.initialize();
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

  Future<void> _onRefresh() async {
    await Future.wait([
      _initializeNfc(),
      _checkConnectivity(),
    ]);
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
    final now = DateTime.now();
    bool isLateScanning = now.hour >= 13;

    if (!_nfcAvailable) {
      await _feedbackService.playErrorFeedback();
      _showSnackBar('NFC is not available on this device', isError: true);
      return;
    }

    if (_nfcService.isScanning) {
      await _feedbackService.playInfoFeedback();
      _showSnackBar('Scan already in progress', isError: true);
      return;
    }

    setState(() {
      _isScanning = true;
    });

    _animationController.repeat(reverse: true);
    _showSnackBar('Hold your device near an NFC card...');

    try {
      // Scan NFC tag
      final nfcData = await _nfcService.scanNfcTag();

      if (nfcData == null || nfcData.uid.isEmpty) {
        _showSnackBar('No UID found on NFC tag', isError: true);
        _stopScanning();
        return;
      }

      // Get location data
      final locationData = await _locationService.getCompleteLocationData();

      // Get device info
      final deviceInfo = await DeviceInfoService().getDeviceDescription();

      // Prioritize data from NFC tag, fallback to user profile
      String? finalUserName = nfcData.userName;
      String? finalUserClass = nfcData.userClass;

      if (finalUserName == null || finalUserClass == null) {
        final profileService = UserProfileService();
        final profileName = await profileService.getUserName();
        final profileClass = await profileService.getUserClass();
        finalUserName ??= profileName;
        finalUserClass ??= profileClass;
      }

      // Create scan log including user/device metadata
      final scanLog = ScanLog(
        uid: nfcData.uid,
        timestamp: DateTime.now(),
        latitude: locationData?.latitude,
        longitude: locationData?.longitude,
        address: locationData?.address,
        city: locationData?.city,
        userName: finalUserName,
        userClass: finalUserClass,
        deviceInfo: deviceInfo,
        isSynced: false,
        isLateScanning: isLateScanning,
      );

      // Save to database
      await _dbHelper.insertScanLog(scanLog);

      // Play success feedback (sound + vibration)
      await _feedbackService.playSuccessFeedback();

      AppLogger.debug('Scan successful for student');

      // Show success dialog
      if (mounted) {
        String? warningMessage;
        if (scanLog.timestamp.hour >= 13) {
          warningMessage = 'Warning: Scan Melepasi Waktu Dibenarkan!';
        }
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => NfcSuccessDialog(
            scanLog: scanLog,
            deviceInfo: scanLog.deviceInfo,
            userName: scanLog.userName,
            userClass: scanLog.userClass,
            warningMessage: warningMessage,
            onClose: () {
              Navigator.of(context).pop();
            },
          ),
        );
      }

      // Auto-sync if online
      _syncService.autoSync();
    } catch (e) {
      AppLogger.error('NFC scan error', e);

      // Play error feedback (sound + vibration)
      await _feedbackService.playErrorFeedback();

      // Show error dialog for timeout
      if (mounted && e.toString().contains('timeout')) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => NfcErrorDialog(
            title: 'Scan Failed',
            message:
                'No NFC tag detected within 5 seconds. Please make sure the NFC tag is close to your device and try again.',
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

  void _showCenterMessage(String message, {bool isError = false, bool isWarning = false}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError 
                      ? Icons.error_outline 
                      : isWarning 
                          ? Icons.warning_amber_outlined
                          : Icons.check_circle_outline,
                  size: 48,
                  color: isError 
                      ? AppTheme.errorRed 
                      : isWarning 
                          ? Colors.orange
                          : AppTheme.successGreen,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Keluar'),
        content: Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen(),
                ),
                (route) => false,
              );
            },
            child: Text(
              'Keluar',
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
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
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          // Header with title and status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NFC Scanner',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: AppTheme.textDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.school,
                                          size: 16,
                                          color: AppTheme.primaryBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Mode Siswa',
                                          style: TextStyle(
                                            color: AppTheme.primaryBlue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: _logout,
                                icon: const Icon(Icons.logout),
                                color: AppTheme.textDark,
                              ),
                            ],
                          ),

                          const SizedBox(height: AppTheme.spacingLarge * 2),

                          // Main scan card
                          Container(
                            height: MediaQuery.of(context).size.height * 0.6,
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
                                            scale: _isScanning
                                                ? _scaleAnimation.value
                                                : 1.0,
                                            child: Container(
                                              width: 160,
                                              height: 160,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryBlue
                                                    .withOpacity(0.08),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  Icons.contactless,
                                                  size: 80,
                                                  color: AppTheme.primaryBlue,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(
                                          height: AppTheme.spacingLarge * 2),

                                      // Instruction text
                                      Text(
                                        _isScanning
                                            ? 'Tempelkan kartu NFC\nke perangkat Anda'
                                            : 'Tekan tombol untuk memulai\nscan kartu NFC',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: AppTheme.textDark,
                                          height: 1.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingLarge * 1.5),

                          // Scan button
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isScanning ? null : _startScan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                disabledBackgroundColor:
                                    AppTheme.primaryBlue.withOpacity(0.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isScanning) ...[
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ] else ...[
                                    Icon(
                                      Icons.contactless,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Flexible(
                                    child: Text(
                                      _isScanning ? 'Scanning...' : 'Mulai Scan NFC',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            // Watermark - positioned behind all content
            Positioned.fill(
              child: Center(
                child: Transform.rotate(
                  angle: -1.0, // Much more diagonal angle
                  child: _buildWatermark(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatermark() {
    return IgnorePointer(
      child: Container(
        child: Text(
          'STUDENT MODE',
          style: TextStyle(
            fontSize: 40,
            color: Colors.grey.withOpacity(0.06),
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}