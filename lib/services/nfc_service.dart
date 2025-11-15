import 'dart:async';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class NfcService {
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  bool _isAvailable = false;
  bool _isScanning = false;
  Completer<String?>? _scanCompleter;

  // Check if NFC is available on the device
  Future<bool> checkAvailability() async {
    try {
      print('Checking NFC availability...');
      _isAvailable = await NfcManager.instance.isAvailable();
      print('NFC available: $_isAvailable');
      return _isAvailable;
    } catch (e) {
      print('Error checking NFC availability: $e');
      _isAvailable = false;
      return false;
    }
  }

  bool get isAvailable => _isAvailable;
  bool get isScanning => _isScanning;

  // Start NFC session and scan for a tag
  Future<String?> scanNfcTag() async {
    print('scanNfcTag called');
    
    if (!_isAvailable) {
      print('NFC not available, rechecking...');
      await checkAvailability();
      if (!_isAvailable) {
        throw Exception('NFC is not available on this device');
      }
    }

    if (_isScanning) {
      throw Exception('NFC scan already in progress');
    }

    _isScanning = true;
    _scanCompleter = Completer<String?>();
    print('Starting NFC session...');

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          print('NFC tag discovered: ${tag.data}');
          try {
            // Extract UID from different tag types
            final uid = _extractUid(tag);
            print('Extracted UID: $uid');
            
            // Complete the scan
            if (!_scanCompleter!.isCompleted) {
              _scanCompleter!.complete(uid);
            }
            
            // Stop the session
            await NfcManager.instance.stopSession();
          } catch (e) {
            print('Error in onDiscovered: $e');
            if (!_scanCompleter!.isCompleted) {
              _scanCompleter!.completeError(e);
            }
            await NfcManager.instance.stopSession(errorMessage: 'Error reading tag');
          }
        },
      );
      print('NFC session started, waiting for tag...');

      // Wait for scan result with timeout
      final result = await _scanCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('NFC scan timeout');
          stopSession();
          throw Exception('NFC scan timeout - no tag detected');
        },
      );

      print('NFC scan completed with result: $result');
      return result;
    } catch (e) {
      print('Error in scanNfcTag: $e');
      await stopSession();
      rethrow;
    } finally {
      _isScanning = false;
      _scanCompleter = null;
    }
  }

  // Extract UID from NFC tag data
  String? _extractUid(NfcTag tag) {
    try {
      // First try to get the basic identifier from tag data
      final data = tag.data;
      
      // Try NfcA (ISO 14443-3A) - Most common
      if (data.containsKey('nfca')) {
        final nfcA = NfcA.from(tag);
        if (nfcA != null && nfcA.identifier.isNotEmpty) {
          return _bytesToHex(nfcA.identifier);
        }
      }

      // Try MiFare (extends NfcA)
      if (data.containsKey('mifare')) {
        final miFare = MiFare.from(tag);
        if (miFare != null && miFare.identifier.isNotEmpty) {
          return _bytesToHex(miFare.identifier);
        }
      }

      // Try NfcB (ISO 14443-3B)
      if (data.containsKey('nfcb')) {
        final nfcB = NfcB.from(tag);
        if (nfcB != null && nfcB.identifier.isNotEmpty) {
          return _bytesToHex(nfcB.identifier);
        }
      }

      // Try NfcF (JIS 6319-4)
      if (data.containsKey('nfcf')) {
        final nfcF = NfcF.from(tag);
        if (nfcF != null && nfcF.identifier.isNotEmpty) {
          return _bytesToHex(nfcF.identifier);
        }
      }

      // Try FeliCa
      if (data.containsKey('felica')) {
        final feliCa = FeliCa.from(tag);
        if (feliCa != null && feliCa.currentIDm.isNotEmpty) {
          return _bytesToHex(feliCa.currentIDm);
        }
      }

      // Try NfcV (ISO 15693)
      if (data.containsKey('nfcv')) {
        final nfcV = NfcV.from(tag);
        if (nfcV != null && nfcV.identifier.isNotEmpty) {
          return _bytesToHex(nfcV.identifier);
        }
      }

      // Try ISO7816 (Smart Cards)
      if (data.containsKey('iso7816')) {
        final iso7816 = Iso7816.from(tag);
        if (iso7816 != null && iso7816.identifier.isNotEmpty) {
          return _bytesToHex(iso7816.identifier);
        }
      }

      // Fallback: try to extract from raw data
      for (final entry in data.entries) {
        if (entry.value is Map) {
          final tagData = entry.value as Map;
          if (tagData.containsKey('identifier')) {
            final identifier = tagData['identifier'];
            if (identifier is List<int> && identifier.isNotEmpty) {
              return _bytesToHex(identifier);
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('Error extracting UID: $e');
      return null;
    }
  }

  // Convert byte array to hex string
  String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  }

  // Stop any active NFC session
  Future<void> stopSession({String? message}) async {
    try {
      await NfcManager.instance.stopSession(errorMessage: message);
      if (_scanCompleter != null && !_scanCompleter!.isCompleted) {
        _scanCompleter!.complete(null);
      }
    } catch (e) {
      print('Error stopping NFC session: $e');
    } finally {
      _isScanning = false;
      _scanCompleter = null;
    }
  }

  // Dispose resources
  void dispose() {
    stopSession();
  }
}
