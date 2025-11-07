# NFC Field Logger

A modern Flutter mobile app for field data logging with NFC scanning capabilities. Scan NFC cards, capture location data, and sync to Google Sheets automatically.

![Flutter](https://img.shields.io/badge/Flutter-3.13.5-blue)
![Dart](https://img.shields.io/badge/Dart-3.1.2-blue)

## Features

### 🎯 Core Functionality
- **NFC Scanning**: Read and log UID from various NFC card types (ISO 14443, MiFare, FeliCa, etc.)
- **Location Tracking**: Automatic GPS coordinates and reverse geocoding to city/address
- **Offline Support**: Works offline with automatic sync when connection is restored
- **Data Export**: Export logs to CSV format
- **Google Sheets Integration**: Auto-sync data to Google Sheets via Web App

### 🎨 User Interface
- **Clean Industrial Design**: Blue-gray color palette (#2563EB primary, #0F172A background)
- **Dark Mode**: Professional dark theme optimized for outdoor visibility
- **Two-Tab Navigation**: Simple navigation between Scan and Log screens
- **Animated Feedback**: NFC icon animation during scanning
- **Status Indicators**: Real-time online/offline/syncing status display

### 📱 Screens

#### Scan Screen
- Large animated NFC icon
- Real-time status chip (Online/Offline/Syncing)
- Scan result display with UID, timestamp, location
- Floating action button for scanning
- Offline mode banner

#### Log/Dashboard Screen
- Statistics cards (Total Scans, Most Active Location)
- Last sync timestamp
- Searchable log list with UID search
- Filter by sync status (show unsynced only)
- Detail popup for each log entry
- Export to CSV and manual sync buttons

## Architecture

```
lib/
├── models/
│   └── scan_log.dart           # Data model for scan logs
├── screens/
│   ├── scan_screen.dart        # NFC scanning interface
│   └── log_screen.dart         # Log list and dashboard
├── services/
│   ├── nfc_service.dart        # NFC scanning logic
│   ├── location_service.dart   # GPS and geocoding
│   ├── database_helper.dart    # SQLite local storage
│   ├── sync_service.dart       # Google Sheets sync
│   └── export_service.dart     # CSV export functionality
├── utils/
│   └── app_theme.dart          # App-wide theme configuration
└── main.dart                   # App entry point
```

## Getting Started

### Prerequisites
- Flutter SDK 3.13.5 or higher
- Dart 3.1.2 or higher
- Android Studio / Xcode for mobile development
- Physical device with NFC capability (NFC doesn't work on emulators)

### Installation

1. **Clone the repository:**
```bash
git clone <repository-url>
cd nfc_field_logger
```

2. **Install dependencies:**
```bash
flutter pub get
```

3. **Run the app:**
```bash
flutter run
```

## Configuration

### Google Sheets Integration

To enable Google Sheets sync, you need to create a Google Apps Script Web App:

1. **Create a new Google Sheet**

2. **Open Apps Script** (Extensions > Apps Script)

3. **Add this code:**
```javascript
function doPost(e) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var data = JSON.parse(e.postData.contents);
  
  data.logs.forEach(function(log) {
    sheet.appendRow([
      log.uid,
      log.timestamp,
      log.latitude,
      log.longitude,
      log.address,
      log.city
    ]);
  });
  
  return ContentService.createTextOutput(JSON.stringify({status: 'success'}))
    .setMimeType(ContentService.MimeType.JSON);
}
```

4. **Deploy as Web App:**
   - Click "Deploy" > "New Deployment"
   - Type: Web app
   - Execute as: Me
   - Who has access: Anyone
   - Copy the Web App URL

5. **Configure in the app:**
   - Use the Settings/Configuration screen (to be added) or SharedPreferences
   - Paste the Web App URL

### Permissions

The app requires the following permissions:

**Android:**
- NFC
- Location (Fine and Coarse)
- Internet
- Storage (for CSV export)

**iOS:**
- NFC Reader
- Location (When In Use and Always)

All permissions are configured in the respective manifest files.

## Usage

### Scanning an NFC Card

1. Navigate to the **Scan** tab
2. Tap the **"Scan NFC"** button
3. Hold your device near an NFC card
4. The app will:
   - Read the NFC UID
   - Capture GPS location
   - Reverse geocode to get city/address
   - Save to local database
   - Auto-sync if online

### Viewing Logs

1. Navigate to the **Log** tab
2. View statistics at the top
3. Use the search bar to find specific UIDs
4. Toggle "Unsynced" filter to see pending syncs
5. Tap any log entry for detailed view

### Exporting Data

1. Go to the **Log** tab
2. Tap **"Export CSV"** button
3. File will be saved to Downloads folder (Android) or Documents (iOS)
4. CSV includes: UID, Timestamp, Latitude, Longitude, Address, City, Sync Status

### Manual Sync

1. Go to the **Log** tab
2. Tap **"Sync Now"** button
3. All unsynced logs will be sent to Google Sheets

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| nfc_manager | ^3.3.0 | NFC card reading |
| geolocator | ^9.0.2 | GPS location access |
| geocoding | ^2.1.0 | Reverse geocoding |
| permission_handler | ^10.4.5 | Runtime permissions |
| sqflite | ^2.3.0 | Local database |
| path_provider | ^2.1.0 | File system paths |
| shared_preferences | ^2.2.0 | Settings storage |
| http | ^1.1.0 | Network requests |
| connectivity_plus | ^4.0.2 | Network status |
| csv | ^5.0.2 | CSV generation |
| intl | ^0.18.0 | Date formatting |
| provider | ^6.0.5 | State management |

## Building for Production

### Android
```bash
flutter build apk --release
# Or for app bundle:
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Troubleshooting

### NFC not working
- Ensure device has NFC hardware
- Check that NFC is enabled in device settings
- NFC only works on physical devices (not emulators)

### Location not detected
- Grant location permissions in app settings
- Ensure GPS/Location Services are enabled
- Try outdoors for better GPS signal

### Sync failing
- Check internet connection
- Verify Google Sheets Web App URL is correct
- Ensure Web App has "Anyone" access permissions

### CSV export failed
- Grant storage permissions
- Check available storage space
- For Android 11+, MANAGE_EXTERNAL_STORAGE permission may be needed

## Development

### Running Tests
```bash
flutter test
```

### Code Analysis
```bash
flutter analyze
```

### Format Code
```bash
flutter format .
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License.

## Support

For issues, questions, or contributions, please open an issue on the GitHub repository.

## Roadmap

- [ ] Settings screen for Google Sheets URL configuration
- [ ] Date range picker for log filtering
- [ ] Batch delete logs
- [ ] Export filtered logs only
- [ ] QR code scanning support
- [ ] Multiple sheet sync targets
- [ ] Data visualization charts
- [ ] Backup and restore functionality

---

Built with ❤️ using Flutter
