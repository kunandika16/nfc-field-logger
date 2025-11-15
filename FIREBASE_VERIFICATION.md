# Firebase Setup Verification Checklist

Error: `PlatformException(null-error)` berarti ada yang belum dikonfigurasi di Firebase Console.

**Verifikasi step-by-step di Firebase Console:**

---

## ✅ Checklist

### 1. Project Info
- [ ] Login ke https://console.firebase.google.com
- [ ] Project "nfc-field-logger" sudah ada & selected
- [ ] Project ID: `nfc-field-logger` (visible di settings)

### 2. Android App Registration
- [ ] Pergi ke **Project Settings** → **Your apps**
- [ ] Ada app Android dengan package: `com.android.nfclogger`
- [ ] App sudah di-register (bukan hanya exist)

### 3. Realtime Database
- [ ] Pergi ke **Realtime Database** (sidebar)
- [ ] Database sudah **CREATED** (bukan hanya "Go to database")
- [ ] Database URL: `https://nfc-field-logger-default-rtdb.asia-southeast1.firebasedatabase.app`
- [ ] Mode: **Test mode** atau **Production** (bukan "Go to database")

### 4. Database Rules
- [ ] Tab **Rules** (di Realtime Database page)
- [ ] Rules sudah di-update dengan:
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
- [ ] Status: **Published** (bukan draft)

### 5. Authentication
- [ ] Pergi ke **Authentication** (sidebar)
- [ ] Tab **Sign-in method**
- [ ] **Anonymous** provider: **ENABLED** (toggle hijau)
- [ ] Jangan ada warning atau error

### 6. API Keys
- [ ] Pergi ke **Project Settings** → **API Keys**
- [ ] Ada minimal 1 API key
- [ ] API key: `AIzaSyDEi1Z7iEkm67zdOimq7WWkraH1L7X7A88` (dari google-services.json)

---

## Jika Ada yang Tidak Terceklis

### Realtime Database Belum Dibuat?
1. Klik **Create Database**
2. Lokasi: `asia-southeast1` (same as project)
3. Mode: **Start in test mode**
4. Klik **Create**

### Anonymous Auth Belum Enabled?
1. Pergi ke **Authentication**
2. Tab **Sign-in method**
3. Klik **Anonymous**
4. Toggle ON (enable)
5. Klik **Save**

### Rules Belum Diupdate?
1. Di Realtime Database, tab **Rules**
2. Copy-paste rules di atas
3. Klik **Publish**

### API Key Bermasalah?
1. Pergi ke **Project Settings** → **API Keys**
2. Buat API key baru jika perlu
3. Update di `android/app/google-services.json`

---

## Setelah Fix

```bash
cd "/Volumes/EKSTERNAL/NFC PROJECT/nfc-field-logger"
fvm flutter clean
fvm flutter pub get
fvm flutter run
```

Cek logs, seharusnya muncul:
```
✅ Firebase initialized successfully
```

Bukan:
```
⛔ Firebase initialization failed
```

---

## Debug Mode

Untuk lihat lebih detail error apa, cek full logs di console:

```
I/flutter: ┌─────────────────────────
I/flutter: │ ✅ Firebase initialized successfully
I/flutter: └─────────────────────────
```

vs

```
I/flutter: ┌─────────────────────────
I/flutter: │ ⚠️ Firebase initialization warning: ...
I/flutter: └─────────────────────────
```

Kalau masih error, screenshot logs dan settings Firebase untuk debugging lebih lanjut.

