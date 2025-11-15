# 🔧 Quick Fix: Sync Error 500

Jika Anda mendapat error "Sync failed with status: 500", ikuti langkah berikut:

---

## ✅ Checklist Cepat

### 1. Test URL di Browser (1 menit)

Buka URL Google Apps Script Anda di browser (Chrome/Firefox/etc):

```
https://script.google.com/macros/s/AKfycbw0X-aUMO6-09o0fJ1yWl1d-sTMI2EUQ5mpO8SKR1oCIZhSkvwnGqrKVtdbAqSB5Q2KbA/exec
```

**✅ Harusnya muncul:**
```json
{
  "status": "success",
  "message": "NFC Field Logger Sync API is running",
  "version": "1.1",
  "timestamp": "2025-11-14T12:30:00.000Z"
}
```

**❌ Jika muncul error atau blank page:**
- Script belum deploy dengan benar
- Lanjut ke langkah 2

---

### 2. Re-Deploy Script (3 menit)

1. Buka [Google Sheets](https://sheets.google.com) Anda
2. **Extensions** > **Apps Script**
3. **Copy script terbaru** dari `GOOGLE_SHEETS_SYNC_SETUP.md`
4. **Paste** dan replace semua code yang ada
5. Klik **Deploy** > **Manage deployments**
6. Klik icon **Archive** (trash) untuk deployment yang lama
7. Klik **+ New deployment**
8. Setting:
   - Type: **Web app**
   - Execute as: **Me**
   - Who has access: **Anyone** ⚠️ PENTING!
9. Klik **Deploy**
10. **Authorize** jika diminta
11. **Copy URL baru**
12. Paste URL baru ke app Settings

---

### 3. Cek Permission (2 menit)

Jika saat deploy muncul warning "Google hasn't verified this app":

1. Klik **Advanced**
2. Klik **Go to [Project Name] (unsafe)**
3. Klik **Allow** untuk SEMUA permission yang diminta

**Permission yang dibutuhkan:**
- See, edit, create, and delete all your Google Sheets spreadsheets
- Connect to an external service

---

### 4. Cek Google Sheets (1 menit)

**Header wajib di baris 1:**

| A | B | C | D | E | F |
|---|---|---|---|---|---|
| UID | Timestamp | Latitude | Longitude | Address | City |

**Cara cepat:**
1. Buka Apps Script editor
2. Pilih function: **initializeSheet**
3. Klik **Run** (▶️)
4. Header akan otomatis dibuat

---

### 5. Test Lagi di App

1. Buka app Settings
2. Pastikan URL sudah benar
3. Tap **Test Connection**
4. Harusnya muncul: **"Connection successful! ✓"**

---

## 🎯 Solusi Tercepat

Jika masih error setelah semua langkah di atas:

### Buat Spreadsheet Baru (5 menit):

1. Buat [Google Sheets baru](https://sheets.google.com)
2. Beri nama: "NFC Logger - NEW"
3. Buat header manual:
   ```
   UID | Timestamp | Latitude | Longitude | Address | City
   ```
4. **Extensions** > **Apps Script**
5. Copy-paste script dari `GOOGLE_SHEETS_SYNC_SETUP.md`
6. **Deploy** sebagai Web app (Anyone)
7. Copy URL baru
8. Update di app Settings

---

## 📝 Common Mistakes

### ❌ URL tidak lengkap
**Salah:** `https://script.google.com/macros/s/AKfycbxxx`  
**Benar:** `https://script.google.com/macros/s/AKfycbxxx/exec` ✅

### ❌ Who has access = "Only myself"
**Salah:** Only myself  
**Benar:** Anyone ✅

### ❌ Execute as = "User accessing the web app"
**Salah:** User accessing the web app  
**Benar:** Me ✅

### ❌ Tidak authorize permission
- Harus klik "Allow" saat deploy pertama kali
- Jika tidak muncul, delete & deploy ulang

---

## 🔍 Debug Log

Cek log error di Apps Script:

1. Buka Apps Script editor
2. Klik **Executions** (di sidebar kiri)
3. Lihat error terbaru
4. Cari "Error in doPost:"

**Common errors:**
- `TypeError: Cannot read property 'contents'` → Deploy ulang
- `ReferenceError: sheet is not defined` → Script salah copy
- `Permission denied` → Authorize ulang

---

## 💡 Tips

1. **Bookmark URL Google Sheets** Anda untuk akses cepat
2. **Screenshot deployment settings** untuk referensi
3. **Test URL di browser** setiap kali deploy
4. **Simpan URL** di notepad sebagai backup

---

## ✅ Verification

Pastikan semua ini sudah benar:

- [ ] URL diakhiri dengan `/exec`
- [ ] URL bisa dibuka di browser dan show JSON
- [ ] Deployment setting = **Anyone**
- [ ] Sudah authorize permission
- [ ] Google Sheets punya header di baris 1
- [ ] Test Connection di app berhasil

Jika semua ✅, sync harusnya langsung berfungsi!

---

**Still have issues?** 

Periksa **Executions** log di Apps Script untuk detail error.
