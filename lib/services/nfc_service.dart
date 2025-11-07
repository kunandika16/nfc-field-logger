import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  bool _isAvailable = false;

  // Check if NFC is available on the device
  Future<bool> checkAvailability() async {
    _isAvailable = await NfcManager.instance.isAvailable();
    return _isAvailable;
  }

  bool get isAvailable => _isAvailable;

  // Start NFC session and scan for a tag
  Future<String?> scanNfcTag() async {
    if (!_isAvailable) {
      throw Exception('NFC is not available on this device');
    }

    String? uid;

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          // Extract UID from different tag types
          uid = _extractUid(tag);
          
          // Stop the session once tag is read
          await NfcManager.instance.stopSession();
        },
      );
    } catch (e) {
      await NfcManager.instance.stopSession(errorMessage: 'Error reading NFC tag');
      rethrow;
    }

    return uid;
  }

  // Extract UID from NFC tag data
  String? _extractUid(NfcTag tag) {
    // Try to get identifier from different NFC tag types
    
    // NfcA (ISO 14443-3A)
    final nfcA = NfcA.from(tag);
    if (nfcA != null && nfcA.identifier.isNotEmpty) {
      return _bytesToHex(nfcA.identifier);
    }

    // NfcB (ISO 14443-3B)
    final nfcB = NfcB.from(tag);
    if (nfcB != null && nfcB.identifier.isNotEmpty) {
      return _bytesToHex(nfcB.identifier);
    }

    // NfcF (JIS 6319-4)
    final nfcF = NfcF.from(tag);
    if (nfcF != null && nfcF.identifier.isNotEmpty) {
      return _bytesToHex(nfcF.identifier);
    }

    // NfcV (ISO 15693)
    final nfcV = NfcV.from(tag);
    if (nfcV != null && nfcV.identifier.isNotEmpty) {
      return _bytesToHex(nfcV.identifier);
    }

    // ISO7816 (Smart Cards)
    final iso7816 = Iso7816.from(tag);
    if (iso7816 != null && iso7816.identifier.isNotEmpty) {
      return _bytesToHex(iso7816.identifier);
    }

    // MiFare
    final miFare = MiFare.from(tag);
    if (miFare != null && miFare.identifier.isNotEmpty) {
      return _bytesToHex(miFare.identifier);
    }

    // FeliCa
    final feliCa = FeliCa.from(tag);
    if (feliCa != null && feliCa.identifier.isNotEmpty) {
      return _bytesToHex(feliCa.identifier);
    }

    return null;
  }

  // Convert byte array to hex string
  String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  }

  // Stop any active NFC session
  Future<void> stopSession({String? message}) async {
    await NfcManager.instance.stopSession(errorMessage: message);
  }

  // Dispose resources
  void dispose() {
    NfcManager.instance.stopSession();
  }
}
