# Firebase Google Services Configuration

## Problem
Anda melihat error: `PlatformException(null-error, Host platform returned null value...)`

Ini berarti `google-services.json` belum dikonfigurasi dengan benar.

---

## Quick Fix (5 menit)

### Step 1: Buat Firebase Project

1. Buka https://console.firebase.google.com
2. Klik **Create a project**
3. Nama: `nfc-field-logger` (atau terserah)
4. Skip Google Analytics → **Create**
5. Tunggu project selesai dibuat

---

### Step 2: Daftarkan App Android

1. Di Firebase Console, klik ikon **Android** (atau **Add app** → Android)
2. Isi form:
   - **Package name**: `com.example.nfc_field_logger`
   - **App nickname**: `NFC Field Logger`
   - **SHA-1**: Biarkan kosong (untuk testing)
3. Klik **Register app**

---

### Step 3: Download google-services.json

1. Klik **Download google-services.json**
2. File akan ter-download secara otomatis

---

### Step 4: Copy ke Project

**Di Mac/Terminal:**

```bash
cp ~/Downloads/google-services.json "/Volumes/EKSTERNAL/NFC PROJECT/nfc-field-logger/android/app/"
```

Atau manual:
1. Buka Finder
2. Download folder → cari `google-services.json`
3. Copy file
4. Navigate ke: `nfc-field-logger/android/app/`
5. Paste file di sini

**Hasil akhir struktur:**
```
nfc-field-logger/
  android/
    app/
      google-services.json  ← File harus di sini
      src/
      build.gradle
```

---

### Step 5: Rebuild App

Di Terminal:
```bash
cd "/Volumes/EKSTERNAL/NFC PROJECT/nfc-field-logger"
fvm flutter clean
fvm flutter pub get
fvm flutter run
```

---

### Step 6: Setup Firebase Database (Sekali saja)

Setelah app running di emulator/device:

1. Di Firebase Console → **Realtime Database**
2. Klik **Create Database**
3. Lokasi: pilih terdekat (misal: `asia-southeast1`)
4. Mode: **Start in test mode**
5. Klik **Create**

---

### Step 7: Update Rules (Security)

1. Tab **Rules** 
2. Copy-paste rules ini:

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

### Step 8: Enable Anonymous Auth

1. Di Firebase Console → **Authentication**
2. Tab **Sign-in method**
3. Cari **Anonymous** → enable toggle
4. Klik **Save**

---

### Step 9: Test Sync

1. App sudah running
2. Scan NFC card
3. Pergi ke **Log** tab
4. Klik tombol **Sync** (icon sync di header)
5. Harus muncul: **"Sync completed successfully"** ✅

---

## Verify Data

Untuk check data sudah masuk ke Firebase:

1. Firebase Console → **Realtime Database**
2. Expand section **users** 
3. Seharusnya ada 1 user ID (random string panjang)
4. Expand user ID → **logs**
5. Data scan Anda seharusnya ada di sini

---

## Masih Error?

### Error: Package name mismatch
**Solusi:** Download `google-services.json` ulang dari Firebase, pastikan package name sama

### Error: Authentication failed
**Solusi:** Buat project Firebase baru, delete & copy ulang `google-services.json`

### Error: Permission denied di database
**Solusi:** Cek rules sudah di-update & anonymous auth sudah enabled

### Data tidak muncul di Firebase
**Solusi:** 
- Cek status Online/Offline di app (harus Online)
- Cek di logs: lihat ada error apa saat sync
- Delete app, rebuild, dan try again

---

## File Locations Reference

**Harus ada di sini:**
```
/Volumes/EKSTERNAL/NFC PROJECT/nfc-field-logger/android/app/google-services.json
```

**Kalau salah lokasi, pindahkan ke folder `app/`:**
```
❌ android/google-services.json          (SALAH)
✅ android/app/google-services.json      (BENAR)
```

---

## Done! 🎉

Sekarang app Anda sudah connected ke Firebase dan siap sync data.

Data akan disimpan secara aman di Firebase cloud dengan authentication per user.

