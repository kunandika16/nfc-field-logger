import 'package:flutter/material.dart';
import '../models/scan_log.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class NfcSuccessDialog extends StatelessWidget {
  final ScanLog scanLog;
  final VoidCallback onClose;

  const NfcSuccessDialog({
    Key? key,
    required this.scanLog,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon with background
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 60,
                color: AppTheme.successGreen,
              ),
            ),

            const SizedBox(height: 24),

            // Success Title
            Text(
              'Scan Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),

            const SizedBox(height: 8),

            // Success Subtitle
            Text(
              'Data has been saved to log',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            // NFC Details
            Container(
              decoration: BoxDecoration(
                color: AppTheme.lightBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.nfc,
                    label: 'NFC UID',
                    value: scanLog.uid,
                    iconColor: AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: DateFormat('dd MMM yyyy, HH:mm').format(scanLog.timestamp),
                    iconColor: AppTheme.primaryBlue,
                  ),
                  if (scanLog.city != null && scanLog.city!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.location_city,
                      label: 'City',
                      value: scanLog.city!,
                      iconColor: AppTheme.primaryBlue,
                    ),
                  ],
                  if (scanLog.address != null && scanLog.address!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.location_on,
                      label: 'Address',
                      value: scanLog.address!,
                      iconColor: AppTheme.primaryBlue,
                    ),
                  ],
                  if (scanLog.latitude != null && scanLog.longitude != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.my_location,
                      label: 'Coordinates',
                      value: '${scanLog.latitude!.toStringAsFixed(6)}, ${scanLog.longitude!.toStringAsFixed(6)}',
                      iconColor: AppTheme.primaryBlue,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Close Button
            SizedBox(
              width: double.infinity,
              height: 50,
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
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
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
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
