import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class NfcTagData {
  final String uid;
  final String? userName;
  final String? userClass;
  final String? rawTextData;

  NfcTagData({
    required this.uid,
    this.userName,
    this.userClass,
    this.rawTextData,
  });
}

class NfcService {
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  bool _isAvailable = false;
  bool _isScanning = false;
  Completer<NfcTagData?>? _scanCompleter;

  // Check if NFC is available on the device
  Future<bool> checkNfcAvailability() async {
    try {
      _isAvailable = await NfcManager.instance.isAvailable();
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  bool get isAvailable => _isAvailable;
  bool get isScanning => _isScanning;

  // Alias for checkNfcAvailability for backward compatibility
  Future<bool> checkAvailability() async {
    return await checkNfcAvailability();
  }

  // Start NFC session and scan for a tag
  Future<NfcTagData?> scanNfcTag() async {
    if (!_isAvailable) {
      await checkAvailability();
      if (!_isAvailable) {
        throw Exception('NFC is not available on this device');
      }
    }

    if (_isScanning) {
      throw Exception('NFC scan already in progress');
    }

    _isScanning = true;
    _scanCompleter = Completer<NfcTagData?>();

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final data = tag.data;
          print('DEBUG: NFC tag data structure: $data');

          try {
            // Extract UID and NDEF data
            final uid = _extractUid(tag);
            print('DEBUG: Extracted UID: $uid');

            // Try to read NDEF data (nama dan kelas)
            final ndefData = _extractNdefData(tag);
            print('DEBUG: NDEF data: "$ndefData"');

            // Also try to read from NfcV, MiFare, or other tag types
            String? alternativeData = _extractAlternativeData(tag);
            print('DEBUG: Alternative data: "$alternativeData"');

            // Use whichever data source has content
            String? finalTextData =
                ndefData?.isNotEmpty == true ? ndefData : alternativeData;
            print('DEBUG: Final text data: "$finalTextData"');

            Map<String, String>? parsedData;
            if (finalTextData != null && finalTextData.isNotEmpty) {
              parsedData = _parseUserData(finalTextData);
            }
            print('DEBUG: Parsed user data: $parsedData');

            final tagData = NfcTagData(
              uid: uid ?? 'Unknown',
              userName: parsedData?['name'],
              userClass: parsedData?['class'],
              rawTextData: ndefData,
            );

            // Complete the scan
            if (!_scanCompleter!.isCompleted) {
              _scanCompleter!.complete(tagData);
            }

            // Stop the session
            await NfcManager.instance.stopSession();
          } catch (e) {
            if (!_scanCompleter!.isCompleted) {
              _scanCompleter!.completeError(e);
            }
            await NfcManager.instance
                .stopSession(errorMessage: 'Error reading tag');
          }
        },
      );

      // Wait for scan result with timeout
      final result = await _scanCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          stopSession();
          throw Exception('NFC scan timeout - no tag detected');
        },
      );

      return result;
    } catch (e) {
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
      return null;
    }
  }

  // Convert byte array to hex string
  String _bytesToHex(List<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  // Extract NDEF text data from tag
  String? _extractNdefData(NfcTag tag) {
    try {
      final ndef = Ndef.from(tag);
      print('DEBUG: NDEF object: $ndef');

      if (ndef != null && ndef.cachedMessage != null) {
        final message = ndef.cachedMessage!;
        print('DEBUG: NDEF message with ${message.records.length} records');

        for (int i = 0; i < message.records.length; i++) {
          final record = message.records[i];
          print('DEBUG: Record $i - TNF: ${record.typeNameFormat}, Type: ${record.type}, Payload length: ${record.payload.length}');

          // Try Text record (type "T")
          if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
              record.type.isNotEmpty &&
              record.type.length == 1 && 
              record.type[0] == 0x54) {
            final textData = _parseTextRecord(record.payload);
            print('DEBUG: Text record data: "$textData"');
            if (textData != null && textData.isNotEmpty) {
              return textData;
            }
          }

          // Try other record types - some apps write as different types
          if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown) {
            try {
              // Try to decode as UTF-8 directly
              final directText = utf8.decode(record.payload);
              print('DEBUG: Direct UTF-8 decode: "$directText"');
              if (directText.contains('Name') || directText.contains('Class')) {
                return directText;
              }
            } catch (e) {
              print('DEBUG: Direct decode failed: $e');
            }
          }

          // Try external type or other formats
          if (record.payload.isNotEmpty) {
            try {
              final rawText = String.fromCharCodes(record.payload);
              print('DEBUG: Raw char codes: "$rawText"');
              if (rawText.contains('Name') || rawText.contains('Class')) {
                return rawText;
              }
            } catch (e) {
              print('DEBUG: Raw decode failed: $e');
            }
          }
        }
      } else {
        print('DEBUG: No NDEF data found or null message');
      }
      return null;
    } catch (e) {
      print('DEBUG: NDEF extraction error: $e');
      return null;
    }
  }

  // Parse NDEF Text Record payload
  String? _parseTextRecord(Uint8List payload) {
    try {
      if (payload.isEmpty) {
        print('DEBUG: Empty payload');
        return null;
      }

      print('DEBUG: Text record payload bytes: ${payload.take(20).toList()}...');

      // First byte contains encoding and language code length
      final statusByte = payload[0];
      final isUtf16 = (statusByte & 0x80) != 0;
      final languageCodeLength = statusByte & 0x3F;

      print('DEBUG: Status byte: $statusByte, UTF16: $isUtf16, Lang length: $languageCodeLength');

      // Skip status byte and language code
      final textStart = 1 + languageCodeLength;

      if (textStart >= payload.length) {
        print('DEBUG: Text start ($textStart) >= payload length (${payload.length})');
        return null;
      }

      final textBytes = payload.sublist(textStart);
      print('DEBUG: Text bytes length: ${textBytes.length}');

      String result;
      if (isUtf16) {
        // UTF-16 encoding
        result = String.fromCharCodes(textBytes);
      } else {
        // UTF-8 encoding
        result = utf8.decode(textBytes);
      }

      print('DEBUG: Decoded text result: "$result"');
      return result;
    } catch (e) {
      print('DEBUG: Text record parse error: $e');
      // Fallback - try direct decode
      try {
        final fallback = utf8.decode(payload);
        print('DEBUG: Fallback decode: "$fallback"');
        return fallback;
      } catch (e2) {
        print('DEBUG: Fallback also failed: $e2');
        return null;
      }
    }
  }

  // Parse user data from text content
  Map<String, String>? _parseUserData(String textData) {
    try {
      print('DEBUG: Raw NFC text data: "$textData"'); // Debug log
      final data = <String, String>{};

      // Try JSON format first: {"Name":"John","Class":"12A"}
      if (textData.startsWith('{') && textData.endsWith('}')) {
        try {
          final jsonData = json.decode(textData) as Map<String, dynamic>;
          if (jsonData['Name'] != null)
            data['name'] = jsonData['Name'].toString();
          if (jsonData['Class'] != null)
            data['class'] = jsonData['Class'].toString();
          // Also try lowercase versions
          if (jsonData['name'] != null)
            data['name'] = jsonData['name'].toString();
          if (jsonData['class'] != null)
            data['class'] = jsonData['class'].toString();
          return data.isNotEmpty ? data : null;
        } catch (e) {
          // Not valid JSON, try other formats
        }
      }

      // Try pipe format: Name:John Doe|Class:12A
      if (textData.contains('|')) {
        final parts = textData.split('|');
        for (final part in parts) {
          if (part.contains(':')) {
            final keyValue = part.split(':');
            if (keyValue.length >= 2) {
              final key = keyValue[0].trim().toLowerCase();
              final value = keyValue.sublist(1).join(':').trim();
              if (key == 'name' && value.isNotEmpty) data['name'] = value;
              if (key == 'class' && value.isNotEmpty) data['class'] = value;
            }
          }
        }
        if (data.isNotEmpty) {
          return data;
        }
      }

      // Try semicolon format: John Doe;12A
      if (textData.contains(';')) {
        final parts = textData.split(';');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          final classValue = parts[1].trim();
          if (name.isNotEmpty) data['name'] = name;
          if (classValue.isNotEmpty) data['class'] = classValue;
          return data.isNotEmpty ? data : null;
        }
      }

      // Try line-based format:
      // Name: John Doe
      // Class: 12A
      final lines = textData.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains(':')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            final key = parts[0].trim().toLowerCase();
            final value = parts.sublist(1).join(':').trim();
            if (key == 'name' && value.isNotEmpty) data['name'] = value;
            if (key == 'class' && value.isNotEmpty) data['class'] = value;
          }
        }
      }

      final result = data.isNotEmpty ? data : null;
      print('DEBUG: Parsed data: $result'); // Debug log
      return result;
    } catch (e) {
      print('DEBUG: Parse error: $e'); // Debug log
      return null;
    }
  }

  // Try to extract data from non-NDEF sources
  String? _extractAlternativeData(NfcTag tag) {
    try {
      final data = tag.data;

      // Try MiFare Classic
      if (data.containsKey('mifare')) {
        final miFare = MiFare.from(tag);
        if (miFare != null) {
          // Note: Reading MiFare data blocks requires authentication
          // which is complex and may not work with all cards
        }
      }

      // Try NfcA
      if (data.containsKey('nfca')) {
        final nfcA = NfcA.from(tag);
        if (nfcA != null) {
          // NfcA tag found but no readable text data
        }
      }

      // Try Ndef Formatable
      if (data.containsKey('ndefformatable')) {
        // This means the tag can be formatted for NDEF but isn't yet
      }

      return null; // For now, return null until we find the right approach
    } catch (e) {
      return null;
    }
  }

  // Stop any active NFC session
  Future<void> stopSession({String? message}) async {
    try {
      await NfcManager.instance.stopSession(errorMessage: message);
      if (_scanCompleter != null && !_scanCompleter!.isCompleted) {
        _scanCompleter!.complete(null);
      }
    } catch (e) {
      // Error stopping session
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
