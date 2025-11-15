# Fix Firebase - Complete Setup

## Status Saat Ini

✅ **App berjalan normal tanpa Firebase** (fallback ke local database)
❌ **Firebase belum bisa sync** (credentials invalid)

---

## Solusi: Setup Firebase Project Baru yang Valid

### Step 1: Buat Project Baru di Firebase

1. Buka https://console.firebase.google.com
2. Klik **Add project** atau **Create a project**
3. Nama project: `nfc-field-logger-new` (atau nama lain)
4. Disable **Google Analytics** (untuk simplicity)
5. Klik **Create project**
6. Tunggu project selesai dibuat (~1-2 menit)

---

### Step 2: Register Android App

1. Di Firebase Dashboard, klik icon **Android** (atau **Get started**)
2. Isi form:
   - **Android package name**: `com.android.nfclogger` ✅ PENTING
   - **App nickname**: `NFC Field Logger`
   - **Debug signing certificate SHA-1**: Biarkan kosong (for now)
3. Klik **Register app**

---

### Step 3: Download google-services.json

1. Layar akan show: "Download google-services.json"
2. Klik **Download google-services.json** (button biru)
3. File akan download ke folder: `~/Downloads/`

---

### Step 4: Replace File di Project

**Cara termudah:**

```bash
# Copy file dari Downloads ke project
cp ~/Downloads/google-services.json "/Volumes/EKSTERNAL/NFC PROJECT/nfc-field-logger/android/app/"
```

**Atau manual:**
1. Buka Finder
2. Download folder → cari `google-services.json` (yang baru download)
3. Copy file
4. Navigate ke: `nfc-field-logger/android/app/`
5. Paste & Replace file lama

---

### Step 5: Rebuild App

```bash
cd "/Volumes/EKSTERNAL/NFC PROJECT/nfc-field-logger"
fvm flutter clean
fvm flutter pub get
fvm flutter run
```

---

### Step 6: Setup Realtime Database

1. Di Firebase Console → **Realtime Database** (sidebar kiri)
2. Klik **Create Database**
3. Lokasi: `asia-southeast1` (atau terdekat)
4. Mode: **Start in test mode**
5. Klik **Create**

**Setup Rules:**

1. Tab **Rules**
2. Replace dengan:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid",
        "logs": {
          ".indexOn": ["timestamp"]
        }
      }
    }
  }
}
```

3. Klik **Publish**

---

### Step 7: Enable Anonymous Auth

1. **Authentication** → **Sign-in method**
2. Cari **Anonymous**
3. Klik toggle untuk enable
4. Klik **Save**

---

### Step 8: Test Sync

```bash
fvm flutter run
```

1. App open → Scan tab → check NFC available
2. Scan NFC card (atau gunakan data lama dari testing)
3. Pergi ke **Log** tab
4. Klik **Sync** button (icon sync di header)
5. Cek notifikasi: **"Sync completed successfully"** ✅

---

### Step 9: Verify di Firebase

1. Firebase Console → **Realtime Database**
2. Expand **users** 
3. Seharusnya ada 1 folder dengan random ID (user ID)
4. Di dalam ada **logs** folder dengan data scan

---

## Troubleshoot

### Masih error PlatformException?

- Pastikan `google-services.json` dari project yang **baru** dibuat (bukan yang lama)
- Pastikan file di lokasi: `android/app/google-services.json`
- Run `fvm flutter clean` sebelum rebuild

### Error saat tap Sync?

- Cek status **Online/Offline** di app (harus Online)
- Pastikan Realtime Database sudah di-create
- Pastikan Anonymous auth sudah enabled

### Data tidak muncul di Firebase?

- Cek Realtime Database sudah di-create
- Cek Rules sudah di-update dengan benar
- Scan NFC dulu sebelum sync

---

## Important Notes

⚠️ **Package name harus cocok:**
- App: `com.android.nfclogger` ✅
- google-services.json: `com.android.nfclogger` ✅
- Firebase project: register dengan `com.android.nfclogger` ✅

⚠️ **Jangan pakai project Firebase lama** (credentials mungkin expired)

⚠️ **Test mode rules** cukup untuk development (tapi perlu rules yang benar untuk production)

---

## Done! 🎉

Setelah semua step, app Anda akan sync ke Firebase dengan normal.

Kalau masih ada error, report details dari:
1. Console logs saat klik Sync
2. Struktur data di Firebase (atau screenshot)

