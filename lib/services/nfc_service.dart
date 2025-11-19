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
  Future<NfcTagData?> scanNfcTag() async {
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
    _scanCompleter = Completer<NfcTagData?>();
    print('Starting NFC session...');

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          print('=== NFC TAG DISCOVERED ===');
          print('Tag data: ${tag.data}');
          
          // Print all available tag types and their data
          final data = tag.data;
          for (final entry in data.entries) {
            print('Tag type: ${entry.key}');
            if (entry.value is Map) {
              final tagData = entry.value as Map;
              for (final subEntry in tagData.entries) {
                print('  ${subEntry.key}: ${subEntry.value}');
              }
            } else {
              print('  Value: ${entry.value}');
            }
          }
          
          try {
            // Extract UID and NDEF data
            final uid = _extractUid(tag);
            print('Extracted UID: $uid');
            
            // Try to read NDEF data (nama dan kelas)
            final ndefData = _extractNdefData(tag);
            print('NDEF data result: $ndefData');
            
            // Also try to read from NfcV, MiFare, or other tag types
            String? alternativeData = _extractAlternativeData(tag);
            print('Alternative data: $alternativeData');
            
            // Use whichever data source has content
            final finalTextData = ndefData ?? alternativeData;
            print('Final text data to parse: $finalTextData');
            
            Map<String, String>? parsedData;
            if (finalTextData != null && finalTextData.isNotEmpty) {
              parsedData = _parseUserData(finalTextData);
              print('Parsed user data: $parsedData');
            }
            
            final tagData = NfcTagData(
              uid: uid ?? 'Unknown',
              userName: parsedData?['nama'],
              userClass: parsedData?['kelas'],
              rawTextData: ndefData,
            );
            
            // Complete the scan
            if (!_scanCompleter!.isCompleted) {
              _scanCompleter!.complete(tagData);
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
        const Duration(seconds: 5),
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

  // Extract NDEF text data from tag
  String? _extractNdefData(NfcTag tag) {
    try {
      print('=== DEBUG: Extracting NDEF data ===');
      final ndef = Ndef.from(tag);
      print('NDEF object: $ndef');
      
      if (ndef != null && ndef.cachedMessage != null) {
        final message = ndef.cachedMessage!;
        print('NDEF message found with ${message.records.length} records');
        
        for (int i = 0; i < message.records.length; i++) {
          final record = message.records[i];
          print('Record $i:');
          print('  - Type Name Format: ${record.typeNameFormat}');
          print('  - Type: ${record.type}');
          print('  - Type as hex: ${record.type.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          print('  - Payload length: ${record.payload.length}');
          print('  - Payload as hex: ${record.payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          
          if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
              record.type.isNotEmpty) {
            // Check if it's a Text record (type "T")
            if (record.type.length == 1 && record.type[0] == 0x54) {
              print('Found Text record, parsing...');
              final textData = _parseTextRecord(record.payload);
              print('Parsed text: "$textData"');
              return textData;
            }
          }
        }
      } else {
        print('No NDEF message found');
      }
      return null;
    } catch (e) {
      print('Error extracting NDEF data: $e');
      return null;
    }
  }

  // Parse NDEF Text Record payload
  String? _parseTextRecord(Uint8List payload) {
    try {
      print('=== DEBUG: Parsing text record ===');
      print('Payload length: ${payload.length}');
      print('Payload bytes: ${payload.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      
      if (payload.isEmpty) {
        print('Empty payload');
        return null;
      }
      
      // First byte contains encoding and language code length
      final statusByte = payload[0];
      final isUtf16 = (statusByte & 0x80) != 0;
      final languageCodeLength = statusByte & 0x3F;
      
      print('Status byte: 0x${statusByte.toRadixString(16).padLeft(2, '0')}');
      print('Is UTF-16: $isUtf16');
      print('Language code length: $languageCodeLength');
      
      // Skip status byte and language code
      final textStart = 1 + languageCodeLength;
      print('Text starts at byte: $textStart');
      
      if (textStart >= payload.length) {
        print('Text start position beyond payload length');
        return null;
      }
      
      final textBytes = payload.sublist(textStart);
      print('Text bytes: ${textBytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      
      String result;
      if (isUtf16) {
        // UTF-16 encoding
        result = String.fromCharCodes(textBytes);
        print('Decoded as UTF-16: "$result"');
      } else {
        // UTF-8 encoding
        result = utf8.decode(textBytes);
        print('Decoded as UTF-8: "$result"');
      }
      
      return result;
    } catch (e) {
      print('Error parsing text record: $e');
      return null;
    }
  }

  // Parse user data from text content
  Map<String, String>? _parseUserData(String textData) {
    try {
      print('=== DEBUG: Parsing user data ===');
      print('Input text: "$textData"');
      print('Text length: ${textData.length}');
      print('Text bytes: ${textData.codeUnits.map((c) => '0x${c.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      
      final data = <String, String>{};
      
      // Try JSON format first: {"nama":"John","kelas":"12A"}
      if (textData.startsWith('{') && textData.endsWith('}')) {
        print('Trying JSON format...');
        try {
          final jsonData = json.decode(textData) as Map<String, dynamic>;
          if (jsonData['nama'] != null) data['nama'] = jsonData['nama'].toString();
          if (jsonData['kelas'] != null) data['kelas'] = jsonData['kelas'].toString();
          print('JSON parsed successfully: $data');
          return data.isNotEmpty ? data : null;
        } catch (e) {
          print('Not valid JSON, trying other formats: $e');
        }
      }
      
      // Try pipe format: nama:John Doe|kelas:12A
      if (textData.contains('|')) {
        print('Trying pipe format...');
        final parts = textData.split('|');
        print('Pipe parts: $parts');
        for (final part in parts) {
          if (part.contains(':')) {
            final keyValue = part.split(':');
            if (keyValue.length >= 2) {
              final key = keyValue[0].trim().toLowerCase();
              final value = keyValue.sublist(1).join(':').trim();
              print('Key: "$key", Value: "$value"');
              if (key == 'nama' && value.isNotEmpty) data['nama'] = value;
              if (key == 'kelas' && value.isNotEmpty) data['kelas'] = value;
            }
          }
        }
        if (data.isNotEmpty) {
          print('Pipe format parsed successfully: $data');
          return data;
        }
      }
      
      // Try semicolon format: John Doe;12A
      if (textData.contains(';')) {
        print('Trying semicolon format...');
        final parts = textData.split(';');
        print('Semicolon parts: $parts');
        if (parts.length >= 2) {
          final nama = parts[0].trim();
          final kelas = parts[1].trim();
          if (nama.isNotEmpty) data['nama'] = nama;
          if (kelas.isNotEmpty) data['kelas'] = kelas;
          print('Semicolon format parsed successfully: $data');
          return data.isNotEmpty ? data : null;
        }
      }
      
      // Try line-based format:
      // Nama: John Doe
      // Kelas: 12A
      print('Trying line-based format...');
      final lines = textData.split('\n');
      print('Lines: $lines');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        print('Processing line $i: "$line"');
        if (line.contains(':')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            final key = parts[0].trim().toLowerCase();
            final value = parts.sublist(1).join(':').trim();
            print('Line - Key: "$key", Value: "$value"');
            if (key == 'nama' && value.isNotEmpty) data['nama'] = value;
            if (key == 'kelas' && value.isNotEmpty) data['kelas'] = value;
          }
        }
      }
      
      print('Final parsed data: $data');
      return data.isNotEmpty ? data : null;
    } catch (e) {
      print('Error parsing user data: $e');
      return null;
    }
  }

  // Try to extract data from non-NDEF sources
  String? _extractAlternativeData(NfcTag tag) {
    try {
      print('=== DEBUG: Trying alternative data extraction ===');
      final data = tag.data;
      
      // Try MiFare Classic
      if (data.containsKey('mifare')) {
        print('Found MiFare tag, attempting to read...');
        final miFare = MiFare.from(tag);
        if (miFare != null) {
          print('MiFare identifier: ${_bytesToHex(miFare.identifier)}');
          // Note: Reading MiFare data blocks requires authentication
          // which is complex and may not work with all cards
        }
      }
      
      // Try NfcA
      if (data.containsKey('nfca')) {
        print('Found NfcA tag');
        final nfcA = NfcA.from(tag);
        if (nfcA != null) {
          print('NfcA sak: ${nfcA.sak}');
          print('NfcA atqa: ${nfcA.atqa}');
        }
      }
      
      // Try Ndef Formatable
      if (data.containsKey('ndefformatable')) {
        print('Found NDEF Formatable tag');
        // This means the tag can be formatted for NDEF but isn't yet
      }
      
      // Check if the tag was written with a different format
      print('Checking for any readable text data in raw format...');
      
      return null; // For now, return null until we find the right approach
    } catch (e) {
      print('Error in alternative data extraction: $e');
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
