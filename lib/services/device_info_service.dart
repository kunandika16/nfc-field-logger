import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  Future<String> getDeviceDescription() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfoPlugin.androidInfo;
        // Debug print full info once (can comment out later)
        // ignore: avoid_print
        print('[DeviceInfo] androidInfo: manufacturer=${info.manufacturer}, brand=${info.brand}, model=${info.model}, device=${info.device}, product=${info.product}, hardware=${info.hardware}, host=${info.host}, board=${info.board}, fingerprint=${info.fingerprint}');

        final manufacturer = (info.manufacturer ?? '').trim();
        final brand = (info.brand ?? '').trim();
        final model = (info.model ?? '').trim();
        final device = (info.device ?? '').trim();
        final product = (info.product ?? '').trim();
        final hardware = (info.hardware ?? '').trim();
        final board = (info.board ?? '').trim();
        final fingerprint = (info.fingerprint ?? '').trim();
        final version = info.version.release ?? '';

        // Build a best-effort identifier with fallbacks
        String vendor = manufacturer.isNotEmpty ? manufacturer : brand;
        if (vendor.isEmpty && product.isNotEmpty) vendor = product;
        if (vendor.isEmpty && hardware.isNotEmpty) vendor = hardware;
        if (vendor.isEmpty && board.isNotEmpty) vendor = board;

        String modelPart = model;
        if (modelPart.isEmpty && device.isNotEmpty) modelPart = device;
        if (modelPart.isEmpty && product.isNotEmpty) modelPart = product;
        if (modelPart.isEmpty && hardware.isNotEmpty) modelPart = hardware;

        final parts = [
          if (vendor.isNotEmpty) vendor,
          if (modelPart.isNotEmpty && modelPart.toLowerCase() != vendor.toLowerCase()) modelPart,
        ];

        final result = parts.join(' - ').trim();
        if (result.isEmpty) {
          // As last resort use fingerprint shortened
          if (fingerprint.isNotEmpty) {
            final shortFp = fingerprint.length > 28 ? fingerprint.substring(0, 28) : fingerprint;
            return 'Device (${shortFp})';
          }
          return 'Unknown Device';
        }
        return result;
      } else if (Platform.isIOS) {
        final info = await _deviceInfoPlugin.iosInfo;
        final name = (info.name ?? '').trim();
        final model = (info.model ?? '').trim();
        final system = info.systemVersion ?? '';
        final parts = [name, model]
            .where((e) => e.isNotEmpty)
            .toList();
        final result = parts.join(' - ').trim();
        if (result.isEmpty) return 'iOS Device';
        return result;
      } else if (Platform.isMacOS) {
        final info = await _deviceInfoPlugin.macOsInfo;
        return 'macOS ${info.osRelease}';
      } else if (Platform.isLinux) {
        final info = await _deviceInfoPlugin.linuxInfo;
        final name = info.name ?? 'Linux';
        final version = info.version ?? '';
        return [name, version].where((e) => e.isNotEmpty).join(' ');
      } else if (Platform.isWindows) {
        final info = await _deviceInfoPlugin.windowsInfo;
        final displayVersion = info.displayVersion ?? info.productName ?? 'Windows';
        return displayVersion;
      }
      return 'Unknown Device';
    } catch (e) {
      // Log the error for debugging
      // ignore: avoid_print
      print('DeviceInfoService error: $e');
      return 'Unknown Device';
    }
  }
}
