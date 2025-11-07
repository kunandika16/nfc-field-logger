# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Development Commands

### Setup
```bash
# Install dependencies
flutter pub get

# Check Flutter/Dart environment
flutter doctor
```

### Running the Application
```bash
# Run in debug mode (default)
flutter run

# Run on specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

**Important**: NFC functionality requires a physical device with NFC hardware. Emulators/simulators do not support NFC.

### Testing & Quality
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Analyze code for issues
flutter analyze

# Format code
flutter format .

# Format specific files
flutter format lib/
```

### Building
```bash
# Android APK (release)
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (release)
flutter build ios --release
```

### Cleaning Build Artifacts
```bash
# Clean build files and caches
flutter clean

# Clean and reinstall dependencies
flutter clean && flutter pub get
```

## Architecture Overview

### Core Design Pattern
This is a **Flutter mobile application** using a **service-oriented architecture**:
- **Models**: Plain data classes (no Provider/Bloc)
- **Services**: Singleton pattern for shared business logic and state
- **Screens**: Stateful widgets that consume services directly
- **No formal state management**: Uses StatefulWidget with direct service calls

### Key Architectural Concepts

#### 1. Singleton Services Pattern
All services use the singleton pattern for shared state access:
```dart
class ServiceName {
  static final ServiceName _instance = ServiceName._internal();
  factory ServiceName() => _instance;
  ServiceName._internal();
}
```

Services are instantiated directly in widgets:
```dart
final NfcService _nfcService = NfcService();
```

#### 2. Data Flow Architecture
```
NFC Tag Scan → NfcService → LocationService → DatabaseHelper → SyncService → Google Sheets
                  ↓              ↓               ↓               ↓
                 UID        GPS+Address      SQLite DB       HTTP POST
```

**Scan Process Flow**:
1. User taps scan button in `ScanScreen`
2. `NfcService.scanNfcTag()` reads NFC tag UID
3. `LocationService.getCompleteLocationData()` captures GPS + reverse geocodes to address
4. `ScanLog` model created with all data
5. `DatabaseHelper.insertScanLog()` saves to local SQLite
6. `SyncService.autoSync()` syncs to Google Sheets if online

**Offline-First Design**: All data saved locally first, synced when connection available

#### 3. Service Responsibilities

**NfcService** (`services/nfc_service.dart`):
- Manages NFC session lifecycle
- Extracts UID from multiple tag types (NfcA, NfcB, NfcF, NfcV, ISO7816, MiFare, FeliCa)
- Converts byte arrays to hex format (e.g., `A1:B2:C3:D4`)

**LocationService** (`services/location_service.dart`):
- Handles location permissions (uses `permission_handler`)
- Gets GPS coordinates (uses `geolocator`)
- Reverse geocodes to human-readable addresses (uses `geocoding`)
- Returns `LocationData` model with coordinates + address

**DatabaseHelper** (`services/database_helper.dart`):
- SQLite database wrapper (uses `sqflite`)
- Single table: `scan_logs`
- Provides CRUD operations, search, filtering, and statistics queries
- Tracks sync status per record (`isSynced` boolean flag)

**SyncService** (`services/sync_service.dart`):
- Monitors network connectivity (uses `connectivity_plus`)
- Syncs unsynced logs to Google Sheets via Apps Script Web App
- Manages sync status: `online`, `offline`, `syncing`, `error`
- Stores configuration in SharedPreferences (Web App URL, auto-sync setting)
- Auto-syncs when connection restored

**ExportService** (`services/export_service.dart`):
- Exports logs to CSV format
- Saves to platform-specific directories (Downloads on Android, Documents on iOS)

#### 4. Google Sheets Integration
The app syncs to Google Sheets via a **Google Apps Script Web App**:
- Web App URL stored in SharedPreferences
- POSTs JSON payload: `{"logs": [{"uid": "...", "timestamp": "...", ...}]}`
- Apps Script appends rows to active sheet
- After successful sync, local records marked as `isSynced = true`

### UI Structure

**Two-Screen App**:
1. **ScanScreen**: Primary interaction—NFC scanning with live status and results
2. **LogScreen**: Dashboard with statistics, log list, search, export, manual sync

**Navigation**: Bottom navigation bar with IndexedStack (keeps both screens alive)

**Theme**: Dark mode industrial design
- Primary: `#2563EB` (blue)
- Background: `#0F172A` (dark blue-gray)
- Defined in `utils/app_theme.dart`

### Permission Requirements

**Android** (configured in `android/app/src/main/AndroidManifest.xml`):
- NFC
- Location (Fine and Coarse)
- Internet
- Storage (for CSV export)

**iOS** (configured in `ios/Runner/Info.plist`):
- NFC Reader Session
- Location When In Use
- Location Always (optional)

Runtime permissions handled by `permission_handler` package, specifically in `LocationService`.

## Development Guidelines

### When Adding New Features

1. **Services**: Add new singleton service in `lib/services/` for new business logic domains
2. **Models**: Add data classes to `lib/models/` for new data structures
3. **Screens**: Add new screens to `lib/screens/` if adding major UI sections
4. **Database Changes**: Modify `DatabaseHelper._onCreate()` and increment database version

### When Working with NFC

- Always test on physical devices (emulators don't support NFC)
- Handle all tag types by checking `NfcA`, `NfcB`, `NfcF`, `NfcV`, `ISO7816`, `MiFare`, `FeliCa`
- Stop NFC sessions properly to avoid resource leaks
- Provide user feedback during scanning (animation, status messages)

### When Working with Location

- Always request permissions before accessing location
- Handle cases where GPS is disabled or permissions denied
- Provide timeout for location requests (currently 10 seconds)
- Reverse geocoding can fail—handle null addresses gracefully

### When Working with Database

- Use transactions for multiple operations
- Always order queries by `timestamp DESC` for newest-first display
- Remember `isSynced` is stored as INTEGER (0/1) in SQLite but boolean in Dart
- Don't forget to close database connections if adding custom queries

### When Working with Sync

- Web App URL must be configured before sync works
- Always check `isOnline()` before attempting sync
- Mark records as synced only after successful HTTP 200 response
- Handle sync failures gracefully—users can manually retry

### Testing Strategy

**Unit Tests**: Test individual services (NFC parsing, database operations, sync logic)
**Widget Tests**: Test screen UI and interactions
**Integration Tests**: Test full scan flow on physical device with NFC

Run tests with `flutter test` from repository root.

## Common Issues & Solutions

### "NFC not available"
- Verify device has NFC hardware: Settings → Connected devices → Connection preferences → NFC
- Check app has NFC permissions in manifest
- Only works on physical devices, not emulators

### "Location permission denied"
- User must grant location permission for geocoding
- Call `LocationService.requestPermission()` to prompt
- Some features degrade gracefully without location (logs UID only)

### "Sync failed"
- Check internet connection (`connectivity_plus` monitors this)
- Verify Google Sheets Web App URL is correct
- Ensure Apps Script deployment set to "Anyone" access
- Check Apps Script has proper permissions to write to sheet

### "Build errors after pub get"
- Run `flutter clean` then `flutter pub get`
- Check Flutter/Dart SDK versions match `pubspec.yaml` requirements
- Ensure Android SDK and Xcode (for iOS) properly configured
