# Panduan Setup Google Sheets Sync

Ikuti langkah-langkah berikut untuk mengaktifkan fitur sync data NFC ke Google Sheets.

---

## Langkah 1: Buat Google Sheets Baru

1. Buka [Google Sheets](https://sheets.google.com)
2. Klik **+ Blank** untuk membuat spreadsheet baru
3. Beri nama spreadsheet, misalnya: **"NFC Field Logger Data"**
4. Buat header di baris pertama dengan kolom-kolom berikut:

   | A | B | C | D | E | F |
   |---|---|---|---|---|---|
   | UID | Timestamp | Latitude | Longitude | Address | City |

---

## Langkah 2: Buka Apps Script Editor

1. Di Google Sheets, klik menu **Extensions** > **Apps Script**
2. Akan terbuka tab baru dengan editor Apps Script
3. Hapus kode default yang ada (`function myFunction() {...}`)

---

## Langkah 3: Paste Script Berikut

Copy dan paste script di bawah ini ke Apps Script editor:

```javascript
/**
 * NFC Field Logger - Google Sheets Sync Script
 * This script receives data from the Flutter app and saves it to Google Sheets
 * 
 * IMPORTANT: Make sure to deploy as Web App with:
 * - Execute as: Me
 * - Who has access: Anyone
 */

// Function to handle POST requests from the app
function doPost(e) {
  try {
    // Log the incoming request for debugging
    Logger.log('Received POST request');
    
    // Get the active spreadsheet and sheet
    var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = spreadsheet.getActiveSheet();
    
    // Check if postData exists
    if (!e || !e.postData || !e.postData.contents) {
      Logger.log('No postData found');
      return ContentService.createTextOutput(JSON.stringify({
        'status': 'error',
        'message': 'No data received'
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    // Parse the JSON data from the request
    var data = JSON.parse(e.postData.contents);
    Logger.log('Parsed data: ' + JSON.stringify(data));
    
    var logs = data.logs;
    
    // Check if logs array exists and has data
    if (!logs || !Array.isArray(logs) || logs.length === 0) {
      Logger.log('No logs in data');
      return ContentService.createTextOutput(JSON.stringify({
        'status': 'error',
        'message': 'No logs provided or logs is not an array'
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    // Log the number of logs received
    Logger.log('Processing ' + logs.length + ' logs');
    
    // Iterate through each log and append to sheet
    var successCount = 0;
    logs.forEach(function(log, index) {
      try {
        // Ensure all values are strings or empty
        var row = [
          (log.uid || '').toString(),
          (log.timestamp || '').toString(),
          (log.latitude !== null && log.latitude !== undefined) ? log.latitude.toString() : '',
          (log.longitude !== null && log.longitude !== undefined) ? log.longitude.toString() : '',
          (log.address || '').toString(),
          (log.city || '').toString()
        ];
        
        sheet.appendRow(row);
        successCount++;
        Logger.log('Added row ' + (index + 1) + ': ' + JSON.stringify(row));
      } catch (rowError) {
        Logger.log('Error adding row ' + (index + 1) + ': ' + rowError.toString());
      }
    });
    
    Logger.log('Successfully added ' + successCount + ' rows');
    
    // Return success response
    return ContentService.createTextOutput(JSON.stringify({
      'status': 'success',
      'message': 'Data saved successfully',
      'count': successCount,
      'total': logs.length
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch (error) {
    // Log the error
    Logger.log('Error in doPost: ' + error.toString());
    Logger.log('Error stack: ' + error.stack);
    
    // Return error response
    return ContentService.createTextOutput(JSON.stringify({
      'status': 'error',
      'message': error.toString(),
      'stack': error.stack
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// Function to handle GET requests (for testing)
function doGet(e) {
  try {
    Logger.log('Received GET request');
    
    return ContentService.createTextOutput(JSON.stringify({
      'status': 'success',
      'message': 'NFC Field Logger Sync API is running',
      'version': '1.1',
      'timestamp': new Date().toISOString()
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      'status': 'error',
      'message': error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// Helper function to initialize sheet with headers (run this once manually)
function initializeSheet() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  
  // Check if headers already exist
  if (sheet.getRange(1, 1).getValue() !== '') {
    Logger.log('Sheet already has data. Skipping initialization.');
    return;
  }
  
  // Add headers
  sheet.appendRow(['UID', 'Timestamp', 'Latitude', 'Longitude', 'Address', 'City']);
  
  // Format headers
  var headerRange = sheet.getRange(1, 1, 1, 6);
  headerRange.setFontWeight('bold');
  headerRange.setBackground('#4285f4');
  headerRange.setFontColor('#ffffff');
  
  Logger.log('Sheet initialized with headers');
}
```

---

## Langkah 4: Deploy Script sebagai Web App

1. Di Apps Script editor, klik tombol **Deploy** (di kanan atas) > **New deployment**

2. Akan muncul dialog "New deployment":
   - Klik icon **⚙️ (gear/settings)** di samping "Select type"
   - Pilih **Web app**

3. Isi konfigurasi deployment:
   - **Description**: `NFC Logger Sync v1` (atau deskripsi lainnya)
   - **Execute as**: Pilih **Me** (email Google Anda)
   - **Who has access**: Pilih **Anyone** ⚠️ PENTING!

4. Klik tombol **Deploy**

5. Akan muncul dialog "Authorize access":
   - Klik **Authorize access**
   - Pilih akun Google Anda
   - Jika muncul warning "Google hasn't verified this app":
     - Klik **Advanced**
     - Klik **Go to [Project Name] (unsafe)**
   - Klik **Allow** untuk memberikan izin

6. Setelah berhasil, akan muncul **Web app URL**
   - URL berbentuk seperti: `https://script.google.com/macros/s/AKfycbxxx.../exec`
   - **COPY URL INI** - Anda akan membutuhkannya!

---

## Langkah 5: Masukkan URL ke Aplikasi

1. Buka aplikasi NFC Field Logger di Android
2. Pergi ke tab **Log**
3. Tap icon **⚙️ Settings** di kanan atas
4. Cari bagian **Google Sheets Web App URL**
5. Paste URL yang Anda copy di langkah 4
6. Tap **Save** atau keluar dari settings (akan auto-save)

---

## Langkah 6: Test Sync

1. Scan NFC card untuk membuat log entry
2. Pergi ke tab **Log**
3. Tap tombol **Sync** (icon sync di header)
4. Jika berhasil:
   - Akan muncul notifikasi **"Sync completed successfully"**
   - Status badge pada log entry akan berubah dari **"Pending"** menjadi **"Synced"**
5. Cek Google Sheets Anda - data seharusnya sudah muncul!

---

## Troubleshooting

### ❌ Error: "Sync failed" atau HTTP 500

**Penyebab:**
- URL salah atau tidak lengkap
- Device tidak terhubung internet
- Script belum di-deploy dengan benar
- Script error atau permission issue
- Google Sheets tidak punya sheet aktif

**Solusi:**

1. **Test URL di Browser:**
   - Buka URL di browser
   - Harus muncul: `{"status":"success","message":"NFC Field Logger Sync API is running",...}`
   - Jika muncul error atau blank, script belum berfungsi

2. **Cek Deployment:**
   - Pastikan URL yang LENGKAP (harus diakhiri dengan `/exec`)
   - Di Apps Script, cek **Deploy** > **Manage deployments**
   - Pastikan "Who has access" = **Anyone**
   - Jika ragu, buat deployment baru (URL akan berubah)

3. **Cek Permission:**
   - Saat pertama deploy, Google akan minta authorize
   - Pastikan sudah klik "Allow" untuk semua permission
   - Jika belum, delete deployment dan deploy ulang

4. **Cek Script:**
   - Pastikan script sudah benar di-copy (tidak ada yang terpotong)
   - Cek **Executions** di Apps Script untuk log error
   - Update ke script versi terbaru dari guide ini

5. **Cek Google Sheets:**
   - Pastikan ada minimal 1 sheet di spreadsheet
   - Sheet pertama harus kosong atau punya header di baris 1
   - Jika masih error, buat spreadsheet baru

6. **Network:**
   - Pastikan device terhubung internet (cek status Online/Offline di app)
   - Try again beberapa saat kemudian (kadang Google server busy)

---

### ❌ Data tidak muncul di Google Sheets

**Penyebab:**
- Header kolom tidak sesuai
- Sheet yang salah dipilih sebagai active sheet

**Solusi:**
1. Pastikan header di baris 1 sudah benar: UID, Timestamp, Latitude, Longitude, Address, City
2. Jika punya multiple sheets, pastikan sheet yang benar dipilih sebagai active

---

### 🔄 Update Script

Jika Anda perlu update script:

1. Edit script di Apps Script editor
2. Klik **Deploy** > **Manage deployments**
3. Klik icon **✏️ Edit** (pensil)
4. Ubah **Version** ke **New version**
5. Klik **Deploy**
6. URL akan tetap sama, tidak perlu update di app

---

## Fitur Auto-Sync

Aplikasi akan otomatis sync data baru jika:
- Device terhubung internet (status Online)
- Auto-sync diaktifkan di Settings
- Ada log entry yang belum di-sync

Anda juga bisa manual sync kapan saja dengan tap tombol Sync di tab Log.

---

## Tips

1. **Backup Data**: Export CSV secara berkala sebagai backup
2. **Monitoring**: Cek Google Sheets untuk memastikan data tersync dengan baik
3. **Performance**: Sync akan lebih cepat jika dilakukan rutin (data sedikit per sync)

---

## Format Data di Google Sheets

Contoh data yang akan muncul:

| UID | Timestamp | Latitude | Longitude | Address | City |
|-----|-----------|----------|-----------|---------|------|
| 04:AE:B0:17:3E:61:81 | 2025-11-14T12:30:45.000Z | -6.914744 | 107.609810 | Jl. Braga No.1, Sumur Bandung | Bandung |
| 04:12:34:56:78:90:AB | 2025-11-14T13:15:22.000Z | -6.200000 | 106.816666 | Jl. Thamrin, Jakarta Pusat | Jakarta |

---

## Security Notes

⚠️ **PENTING:**
- URL Web App bersifat PUBLIC - siapa saja yang punya URL bisa kirim data
- Jangan share URL ke orang lain
- Jika URL bocor, buat deployment baru (URL akan berubah)
- Data di Google Sheets bersifat private (hanya Anda yang bisa akses)

---

## Butuh Bantuan?

Jika masih ada masalah:
1. Cek log error di Apps Script: **Executions** (di sidebar kiri)
2. Test URL dengan browser: Buka URL di browser, harus muncul JSON response
3. Cek permission di Google Sheets: Pastikan script punya akses

---

**Setup selesai! 🎉**

Aplikasi Anda sekarang sudah terhubung dengan Google Sheets dan siap untuk sync data NFC scan otomatis.
