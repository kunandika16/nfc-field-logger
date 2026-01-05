import 'package:flutter/material.dart';
import '../models/scan_log.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class NfcSuccessDialog extends StatelessWidget {
  final ScanLog scanLog;
  final VoidCallback onClose;
  final String? deviceInfo;
  final String? userName;
  final String? userClass;
  final String? warningMessage;

  const NfcSuccessDialog({
    Key? key,
    required this.scanLog,
    required this.onClose,
    this.deviceInfo,
    this.userName,
    this.userClass,
    this.warningMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;

    return Dialog(
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
                  // Icon berubah jika warning
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (warningMessage != null && warningMessage!.isNotEmpty)
                          ? AppTheme.warningOrange.withOpacity(0.1)
                          : AppTheme.successGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (warningMessage != null && warningMessage!.isNotEmpty)
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle,
                      size: 32,
                      color: (warningMessage != null && warningMessage!.isNotEmpty)
                          ? AppTheme.warningOrange
                          : AppTheme.successGreen,
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
                      onPressed: onClose,
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
                      'Scan Berhasil!',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Data telah disimpan ke dalam log',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),

                    // Warning message jika ada
                    if (warningMessage != null && warningMessage!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.warningOrange,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                warningMessage!,
                                style: TextStyle(
                                  color: AppTheme.warningOrange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // UID Card (Primary)
                    _buildPrimaryCard(),

                    const SizedBox(height: 16),

                    // User Info Section (if available)
                    if ((userName != null && userName!.isNotEmpty) ||
                        (userClass != null && userClass!.isNotEmpty))
                      _buildUserInfoSection(),

                    const SizedBox(height: 16),

                    // Location & Time Section
                    _buildLocationTimeSection(),

                    // Device Info (if available)
                    if (deviceInfo != null && deviceInfo!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDeviceInfoSection(),
                    ],

                    const SizedBox(height: 24),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.done_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Selesai',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }

  // Primary UID Card
  Widget _buildPrimaryCard() {
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
                      scanLog.uid,
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

  // User Information Section
  Widget _buildUserInfoSection() {
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
          if (userName != null && userName!.isNotEmpty)
            _buildCompactDetailRow(
              icon: Icons.person_outline,
              label: 'Nama',
              value: userName!,
              iconColor: AppTheme.successGreen,
            ),
          if (userName != null &&
              userName!.isNotEmpty &&
              userClass != null &&
              userClass!.isNotEmpty)
            const SizedBox(height: 12),
          if (userClass != null && userClass!.isNotEmpty)
            _buildCompactDetailRow(
              icon: Icons.school_outlined,
              label: 'Kelas',
              value: userClass!,
              iconColor: AppTheme.successGreen,
            ),
        ],
      ),
    );
  }

  // Location and Time Section
  Widget _buildLocationTimeSection() {
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
          _buildCompactDetailRow(
            icon: Icons.access_time,
            label: 'Waktu',
            value: DateFormat('dd MMM yyyy, HH:mm').format(scanLog.timestamp),
            iconColor: AppTheme.warningOrange,
          ),
          const SizedBox(height: 12),
          _buildCompactDetailRow(
            icon: Icons.location_city,
            label: 'Kota',
            value: (scanLog.city == null || scanLog.city!.isEmpty)
                ? 'Tidak diketahui'
                : scanLog.city!,
            iconColor: AppTheme.warningOrange,
          ),
          const SizedBox(height: 12),
          _buildCompactDetailRow(
            icon: Icons.location_on,
            label: 'Alamat',
            value: (scanLog.address == null || scanLog.address!.isEmpty)
                ? 'Tidak diketahui'
                : scanLog.address!,
            iconColor: AppTheme.warningOrange,
          ),
          if (scanLog.latitude != null && scanLog.longitude != null) ...[
            const SizedBox(height: 12),
            _buildCompactDetailRow(
              icon: Icons.my_location,
              label: 'Koordinat',
              value:
                  '${scanLog.latitude!.toStringAsFixed(6)}, ${scanLog.longitude!.toStringAsFixed(6)}',
              iconColor: AppTheme.warningOrange,
            ),
          ],
        ],
      ),
    );
  }

  // Device Information Section
  Widget _buildDeviceInfoSection() {
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
            'Informasi Device',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildCompactDetailRow(
            icon: Icons.devices_other,
            label: 'Device',
            value: deviceInfo!,
            iconColor: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  // Compact Detail Row for sections
  Widget _buildCompactDetailRow({
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

  // Legacy method for backward compatibility (if needed)
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return _buildCompactDetailRow(
      icon: icon,
      label: label,
      value: value,
      iconColor: iconColor,
    );
  }
}
