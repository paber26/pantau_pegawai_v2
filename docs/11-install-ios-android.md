# Panduan Install PantauPegawai di iOS dan Android

## A. Install di iPhone (iOS)

### Prasyarat

- Mac dengan Xcode terinstall
- iPhone terhubung via kabel USB
- Apple ID (gratis)

---

### Langkah 1 — Setup Signing di Xcode (sekali saja)

1. Buka project di Xcode:

   ```bash
   open "/Users/bernaldonapitupulu/Documents/Pawai/pantau_pegawai_v2/pantau_pegawai/ios/Runner.xcworkspace"
   ```

   > Buka `.xcworkspace` bukan `.xcodeproj`

2. Di sidebar kiri → bagian **TARGETS** → klik **Runner**

3. Klik tab **"Signing & Capabilities"** di panel tengah

4. Centang **"Automatically manage signing"** ✅

5. Di **Team** → klik dropdown → **"Add an Account..."**
   - Login dengan Apple ID kamu (gratis)
   - Pilih Apple ID sebagai Team

6. **Bundle Identifier** otomatis terisi: `com.pawai.pantauPegawai`

7. Pastikan muncul:
   - **Provisioning Profile**: Xcode Managed Profile
   - **Signing Certificate**: Apple Development: [email kamu]

---

### Langkah 2 — Build & Install ke iPhone

**Opsi A — Dari terminal:**

```bash
cd "/Users/bernaldonapitupulu/Documents/Pawai/pantau_pegawai_v2/pantau_pegawai"
flutter run --release -d 00008110-000E39A936C0E01E
```

**Opsi B — Dari Xcode:**

- Pilih **"Bernaldo Napitupulu's iPhone"** di dropdown device (toolbar atas)
- Klik tombol **▶ Run** (segitiga hijau)
- Tunggu build selesai (~5-10 menit pertama kali)

---

### Langkah 3 — Trust Developer di iPhone

Setelah app ter-install, pertama kali buka akan muncul error "Untrusted Developer":

1. **Settings → General → VPN & Device Management**
2. Tap nama Apple ID kamu di bawah "Developer App"
3. Tap **"Trust [nama Apple ID]"** → **Trust**
4. Buka app dari home screen — sudah bisa berjalan!

---

### Catatan Penting iOS

| Item         | Keterangan                                                   |
| ------------ | ------------------------------------------------------------ |
| Masa berlaku | App berlaku **7 hari** dengan akun gratis                    |
| Re-install   | Setelah 7 hari, ulangi Langkah 2                             |
| Jumlah app   | Maksimal 3 app per device dengan akun gratis                 |
| Debug mode   | Tidak bisa dibuka dari home screen, harus via terminal/Xcode |
| Release mode | Bisa dibuka dari home screen setelah Trust                   |

---

## B. Install di Android

### Build APK

```bash
cd "/Users/bernaldonapitupulu/Documents/Pawai/pantau_pegawai_v2/pantau_pegawai"
flutter build apk --release
```

Proses pertama kali membutuhkan waktu 15-30 menit karena download NDK (~1GB).
Build berikutnya jauh lebih cepat (~3-5 menit).

File APK ada di:

```
build/app/outputs/flutter-apk/app-release.apk (42.4MB)
```

### Install ke Android

**Opsi A — Via kabel USB:**

```bash
flutter install
```

Pastikan **USB Debugging** aktif di Android (Settings → Developer Options).

**Opsi B — Transfer file:**

1. Copy `app-release.apk` ke Android (via WhatsApp, Google Drive, kabel)
2. Buka file APK di Android
3. Aktifkan **"Install from unknown sources"** jika diminta:
   - Settings → Security → Install unknown apps → izinkan dari browser/file manager
4. Tap **Install**

### Prasyarat Android

- Android 5.0 (API 21) atau lebih baru
- Aktifkan "Install from unknown sources"

---

## C. Troubleshooting

### iOS: "No application found for TargetPlatform.ios"

**Penyebab:** Terminal tidak berada di folder Flutter project.
**Solusi:** Gunakan path lengkap:

```bash
cd "/Users/bernaldonapitupulu/Documents/Pawai/pantau_pegawai_v2/pantau_pegawai"
flutter run --release -d 00008110-000E39A936C0E01E
```

### iOS: "Provisioning profile doesn't include the currently selected device"

**Solusi:** Di Xcode → Signing & Capabilities → klik **Register Device**

### iOS: App crash saat dibuka

**Solusi:** Pastikan sudah Trust developer di Settings iPhone

### Android: "App not installed"

**Solusi:** Hapus versi lama app dulu, lalu install ulang

### Android: Build gagal dengan "JDK 17 or higher is required"

**Solusi:**

```bash
brew install --cask temurin@17
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
source ~/.zshrc
```
