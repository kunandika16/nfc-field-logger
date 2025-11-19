import 'package:flutter/services.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

/// Service untuk mengelola sound effect dan haptic feedback
class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  bool _canVibrate = false;

  /// Initialize service dan cek device capabilities
  Future<void> initialize() async {
    // Check if device can vibrate
    _canVibrate = await Vibrate.canVibrate;
  }

  /// Play success feedback (scan berhasil)
  Future<void> playSuccessFeedback() async {
    // Haptic feedback - pattern untuk sukses (short-long-short)
    if (_canVibrate) {
      Vibrate.vibrate(); // Short vibration
    }
    
    // System sound untuk sukses
    await SystemSound.play(SystemSoundType.click);
  }

  /// Play error feedback (scan gagal)
  Future<void> playErrorFeedback() async {
    // Haptic feedback - pattern untuk error (long vibration)
    if (_canVibrate) {
      try {
        // Pattern: vibrate for 500ms
        final Iterable<Duration> pauses = [
          const Duration(milliseconds: 0),
          const Duration(milliseconds: 500),
        ];
        Vibrate.vibrateWithPauses(pauses);
      } catch (e) {
        // Fallback to simple vibrate
        Vibrate.vibrate();
      }
    }
    
    // System sound untuk error
    // Note: iOS dan beberapa Android tidak punya sound khusus untuk alert
    // Kita gunakan system sound yang tersedia
    await SystemSound.play(SystemSoundType.alert);
  }

  /// Play info feedback (untuk notifikasi umum)
  Future<void> playInfoFeedback() async {
    // Light haptic untuk info
    if (_canVibrate) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Play button tap feedback
  Future<void> playTapFeedback() async {
    await HapticFeedback.selectionClick();
  }

  /// Custom vibration pattern
  Future<void> vibrate({
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    if (_canVibrate) {
      Vibrate.vibrate();
    }
  }
}
