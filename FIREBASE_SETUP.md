# Firebase Automatic Sync Setup Guide

## Langkah 1: Buat Firebase Project

1. Buka [Firebase Console](https://console.firebase.google.com)
2. Klik **Create a project**
3. Masukkan nama: `nfc-field-logger` (atau nama lain sesuai pilihan)
4. Klik **Continue**
5. Disable Google Analytics (optional) → **Create project**
6. Tunggu project dibuat

---

## Langkah 2: Setup Firebase untuk Android

### 2a. Register App Android

1. Di Firebase Console, klik tombol **Android** (atau pilih **Add app**)
2. Isi formulir:
   - **Android package name**: `com.example.nfc_field_logger`
   - **App nickname**: `NFC Field Logger`
   - **Debug signing certificate SHA-1**: (leave blank for now)
3. Klik **Register app**

### 2b. Download google-services.json

1. Klik **Download google-services.json**
2. Copy file ke: `android/app/google-services.json`
3. Klik **Next**

### 2c. Add Firebase SDK

Sudah dilakukan di `pubspec.yaml` saat setup.

---

## Langkah 3: Setup Firebase Database Rules

1. Di Firebase Console, pergi ke **Realtime Database**
2. Klik **Create Database**
3. Pilih lokasi terdekat (misal: asia-southeast1 untuk Indonesia)
4. Pilih mode: **Start in test mode**
5. Klik **Create**

### Update Database Rules:

1. Pergi ke tab **Rules**
2. Replace dengan rules berikut:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid",
        "logs": {
          ".indexOn": ["timestamp"]
        },
        "exports": {
          ".indexOn": ["timestamp"]
        }
      }
    }
  }
}
```

3. Klik **Publish**

---

## Langkah 4: Test Sync

1. Build dan run aplikasi
2. Scan NFC card untuk membuat log
3. Pergi ke tab **Log**
4. Tap tombol **Sync** 
5. Jika berhasil, akan muncul notifikasi **"Sync completed successfully"**

---

## Langkah 5: Verify Data di Firebase

1. Di Firebase Console, pergi ke **Realtime Database**
2. Expand section **users**
3. Data Anda seharusnya sudah muncul dengan struktur:
   ```
   users/
     {user-id}/
       logs/
         {uid_timestamp}/
           uid: "04:AE:B0:..."
           timestamp: "2025-11-15T..."
           latitude: -6.914744
           longitude: 107.609810
           address: "..."
           city: "Jakarta"
   ```

---

## Troubleshooting

### ❌ Error: PlatformException (null-error)

**Penyebab:**
- `google-services.json` belum di-copy ke `android/app/`
- Firebase project belum di-setup
- Package name di `google-services.json` tidak sesuai dengan app

**Solusi:**
1. **Download `google-services.json`:**
   - Di Firebase Console, pilih project
   - Klik icon **⚙️ Settings** → **Project Settings**
   - Tab **General** → klik **Download** (tombol di bawah Android app)

2. **Copy file ke lokasi yang benar:**
   ```
   android/app/google-services.json
   ```

3. **Verifikasi package name:**
   - Di `android/app/build.gradle`, cari baris:
   ```gradle
   applicationId "com.example.nfc_field_logger"
   ```
   - Package name harus sama di Firebase project settings

4. **Clean & Rebuild:**
   ```bash
   fvm flutter clean
   fvm flutter pub get
   fvm flutter run
   ```

5. **Jika masih error:**
   - Delete file: `android/app/google-services.json`
   - Buat Firebase project baru
   - Download `google-services.json` yang baru
   - Copy ulang ke `android/app/`

### ❌ Firebase not initialized

**Solusi:**
- Pastikan `google-services.json` sudah di-copy ke `android/app/`
- Run `fvm flutter clean` dan `fvm flutter pub get`
- Rebuild app

### ❌ Permission denied

**Solusi:**
- Cek Firebase Database Rules (harus sesuai dengan rules di atas)
- Pastikan anonymous auth diaktifkan di **Authentication > Sign-in method > Anonymous**

### ❌ Data tidak muncul di Firebase

**Solusi:**
- Pastikan internet connection aktif (cek status Online di app)
- Cek logs di app: Scan → Log → lihat sync status
- Cek Firebase Realtime Database di console untuk melihat struktur data

---

## Fitur Auto-Sync

Setelah setup:
- ✅ Data otomatis sync ke Firebase saat klik Sync button
- ✅ Automatic sync saat ada koneksi internet (jika enabled di settings)
- ✅ Pending status untuk data yang belum sync
- ✅ Data tersimpan di Firebase dengan authentication per user

---

## Export Data dari Firebase

Di masa depan, bisa buat export ke Google Sheets atau CSV langsung dari Firebase data.

Untuk sekarang, data sudah tersimpan aman di Firebase dan bisa dilihat di console.

---

## Security Notes

- ⚠️ Menggunakan anonymous authentication (user tidak perlu login)
- ⚠️ Setiap user punya unique ID dan hanya bisa akses data mereka sendiri
- ⚠️ Rules mencegah user lain membaca/menulis data Anda

