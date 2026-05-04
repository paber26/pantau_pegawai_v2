# Panduan Install PantauPegawai di iPhone (Release Mode Gratis)

## Prasyarat

- Mac dengan Xcode terinstall
- iPhone terhubung via kabel USB
- Apple ID (gratis, tidak perlu bayar $99/tahun)

---

## Langkah 1 — Buka Project di Xcode

Di Xcode yang sudah terbuka, klik **"Runner"** di pojok kanan atas
(terlihat di screenshot: `Runner ... ments/Pawai/pantau_pegawai_v2/ios`)

Atau dari terminal:

```bash
open pantau_pegawai/ios/Runner.xcworkspace
```

> **Penting:** Buka file `.xcworkspace` bukan `.xcodeproj`

---

## Langkah 2 — Setup Signing dengan Apple ID Gratis

1. Di Xcode, klik **Runner** di sidebar kiri (PROJECT section)
2. Klik tab **"Signing & Capabilities"**
3. Pastikan **"Automatically manage signing"** dicentang ✅
4. Di dropdown **Team**:
   - Klik dropdown → pilih **"Add an Account..."**
   - Login dengan Apple ID kamu (bisa Apple ID biasa, gratis)
   - Setelah login, pilih Apple ID kamu sebagai Team
5. Xcode akan otomatis buat **provisioning profile**

---

## Langkah 3 — Ganti Bundle Identifier (jika error)

Kalau muncul error "Bundle identifier already in use":

1. Masih di tab **Signing & Capabilities**
2. Ubah **Bundle Identifier** dari `id.go.bps.pantaupegawai` menjadi sesuatu yang unik, contoh:
   ```
   com.bernaldo.pantaupegawai
   ```

---

## Langkah 4 — Pilih Target Device

Di toolbar atas Xcode:

- Klik dropdown device (sebelah nama scheme "Runner")
- Pilih **"Bernaldo Napitupulu's iPhone"** (iPhone kamu)

---

## Langkah 5 — Build & Install

**Opsi A — Dari terminal (lebih cepat):**

```bash
cd pantau_pegawai
flutter run --release -d 00008110-000E39A936C0E01E
```

**Opsi B — Dari Xcode:**

- Klik tombol **▶ Run** (segitiga hijau) di pojok kiri atas
- Tunggu proses build selesai (5-10 menit pertama kali)

---

## Langkah 6 — Trust Developer di iPhone

Setelah app ter-install, pertama kali buka akan muncul error "Untrusted Developer".

1. Di iPhone: **Settings → General → VPN & Device Management**
2. Tap nama Apple ID kamu di bawah "Developer App"
3. Tap **"Trust [nama Apple ID]"**
4. Tap **Trust** lagi untuk konfirmasi
5. Buka app dari home screen — sekarang bisa berjalan!

---

## Catatan Penting

| Item         | Keterangan                                                |
| ------------ | --------------------------------------------------------- |
| Masa berlaku | App berlaku **7 hari** dengan akun gratis                 |
| Re-install   | Setelah 7 hari, ulangi langkah 5 untuk re-install         |
| Jumlah app   | Maksimal 3 app berbeda per device dengan akun gratis      |
| Distribusi   | Tidak bisa dibagikan ke orang lain (hanya device sendiri) |

Untuk distribusi ke banyak pegawai, butuh **Apple Developer Program** ($99/tahun)
atau gunakan **TestFlight** (butuh akun berbayar juga).

---

## Troubleshooting

### Error: "Provisioning profile doesn't include the currently selected device"

→ Di Xcode: **Runner → Signing & Capabilities → Register Device**

### Error: "No signing certificate"

→ Pastikan sudah login Apple ID di Xcode: **Xcode → Settings → Accounts**

### App crash saat dibuka

→ Cek apakah sudah Trust developer di Settings iPhone

### "Could not launch app" dari terminal

→ Pastikan iPhone tidak terkunci saat proses install
