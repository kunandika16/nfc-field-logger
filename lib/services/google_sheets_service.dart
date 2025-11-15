import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_log.dart';
import '../utils/logger.dart';
import 'sync_service.dart';

class GoogleSheetsService {
  static final GoogleSheetsService _instance = GoogleSheetsService._internal();
  factory GoogleSheetsService() => _instance;
  GoogleSheetsService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      sheets.SheetsApi.spreadsheetsScope,
      sheets.SheetsApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  sheets.SheetsApi? _sheetsApi;

  // SharedPreferences keys
  static const String _spreadsheetIdKey = 'google_spreadsheet_id';
  static const String _spreadsheetNameKey = 'google_spreadsheet_name';

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  // Initialize and check if user is already signed in
  Future<void> initialize() async {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
    });

    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      AppLogger.error('Error signing in silently', e);
    }
  }

  // Sign in with Google
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        final auth = await _googleSignIn.authenticatedClient();
        if (auth != null) {
          _sheetsApi = sheets.SheetsApi(auth);
        }
      }
      return account;
    } catch (e) {
      AppLogger.error('Error signing in', e);
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _sheetsApi = null;
  }

  // Create a new spreadsheet
  Future<Map<String, String>?> createSpreadsheet(String title) async {
    try {
      if (_sheetsApi == null) {
        final auth = await _googleSignIn.authenticatedClient();
        if (auth == null) {
          throw Exception('Not authenticated');
        }
        _sheetsApi = sheets.SheetsApi(auth);
      }

      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: title),
        sheets: [
          sheets.Sheet(
            properties: sheets.SheetProperties(title: 'Scan Logs'),
            data: [
              sheets.GridData(
                rowData: [
                  sheets.RowData(
                    values: [
                      sheets.CellData(
                        userEnteredValue: sheets.ExtendedValue(stringValue: 'UID'),
                        userEnteredFormat: sheets.CellFormat(
                          textFormat: sheets.TextFormat(bold: true),
                        ),
                      ),
                      sheets.CellData(
                        userEnteredValue: sheets.ExtendedValue(stringValue: 'Timestamp'),
                        userEnteredFormat: sheets.CellFormat(
                          textFormat: sheets.TextFormat(bold: true),
                        ),
                      ),
                      sheets.CellData(
                        userEnteredValue: sheets.ExtendedValue(stringValue: 'Latitude'),
                        userEnteredFormat: sheets.CellFormat(
                          textFormat: sheets.TextFormat(bold: true),
                        ),
                      ),
                      sheets.CellData(
                        userEnteredValue: sheets.ExtendedValue(stringValue: 'Longitude'),
                        userEnteredFormat: sheets.CellFormat(
                          textFormat: sheets.TextFormat(bold: true),
                        ),
                      ),
                      sheets.CellData(
                        userEnteredValue: sheets.ExtendedValue(stringValue: 'Address'),
                        userEnteredFormat: sheets.CellFormat(
                          textFormat: sheets.TextFormat(bold: true),
                        ),
                      ),
                      sheets.CellData(
                        userEnteredValue: sheets.ExtendedValue(stringValue: 'City'),
                        userEnteredFormat: sheets.CellFormat(
                          textFormat: sheets.TextFormat(bold: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final created = await _sheetsApi!.spreadsheets.create(spreadsheet);
      
      if (created.spreadsheetId != null) {
        await saveSpreadsheetId(created.spreadsheetId!, title);
        final url = getSpreadsheetUrl(created.spreadsheetId!);
        // Also save to SyncService so other screens (Log/Settings) can open it
        await SyncService().setSpreadsheetUrl(url);
        return {
          'id': created.spreadsheetId!,
          'name': title,
          'url': url,
        };
      }
      return null;
    } catch (e) {
      AppLogger.error('Error creating spreadsheet', e);
      return null;
    }
  }

  // Append data to spreadsheet
  Future<bool> appendData(String spreadsheetId, List<ScanLog> logs) async {
    try {
      if (_sheetsApi == null) {
        final auth = await _googleSignIn.authenticatedClient();
        if (auth == null) {
          throw Exception('Not authenticated');
        }
        _sheetsApi = sheets.SheetsApi(auth);
      }

      final values = logs.map((log) {
        final formattedTimestamp = 
            '${log.timestamp.year}-${log.timestamp.month.toString().padLeft(2, '0')}-${log.timestamp.day.toString().padLeft(2, '0')} ' +
            '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
        
        return [
          log.uid,
          formattedTimestamp,
          log.latitude?.toString() ?? '',
          log.longitude?.toString() ?? '',
          log.address ?? '',
          log.city ?? '',
        ];
      }).toList();

      final valueRange = sheets.ValueRange(
        values: values,
      );

      await _sheetsApi!.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        'Scan Logs!A:F',
        valueInputOption: 'RAW',
      );

      return true;
    } catch (e) {
      AppLogger.error('Error appending data to spreadsheet', e);
      return false;
    }
  }

  // Save spreadsheet ID and name
  Future<void> saveSpreadsheetId(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spreadsheetIdKey, id);
    await prefs.setString(_spreadsheetNameKey, name);
  }

  // Get saved spreadsheet ID
  Future<String?> getSavedSpreadsheetId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_spreadsheetIdKey);
  }

  // Get saved spreadsheet name
  Future<String?> getSavedSpreadsheetName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_spreadsheetNameKey);
  }

  // Clear saved spreadsheet
  Future<void> clearSavedSpreadsheet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_spreadsheetIdKey);
    await prefs.remove(_spreadsheetNameKey);
  }

  // Get spreadsheet URL
  String getSpreadsheetUrl(String spreadsheetId) {
    return 'https://docs.google.com/spreadsheets/d/$spreadsheetId';
  }
}
