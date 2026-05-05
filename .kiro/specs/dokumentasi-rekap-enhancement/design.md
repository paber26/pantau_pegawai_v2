# Design Document: dokumentasi-rekap-enhancement

## Overview

Fitur ini mencakup empat area peningkatan pada aplikasi Flutter PantauPegawai:

1. **DokumentasiScreen** — Halaman `/pegawai/dokumentasi` diubah agar menggunakan `adminDokumentasiNotifierProvider` sehingga semua pegawai dapat melihat dokumentasi seluruh rekan kerja.
2. **RiwayatDokumentasiScreen** — Halaman `/pegawai/riwayat` dipastikan hanya menampilkan data milik user yang sedang login via `myDokumentasiNotifierProvider`.
3. **Bulk Import Proyek** — Tombol "Import Proyek" ditambahkan di `KegiatanListScreen` (admin) untuk memasukkan 65 proyek sekaligus secara idempotent dengan deadline 31 Desember 2026.
4. **RekapUploadScreen** — Halaman baru `/admin/rekap-upload` menampilkan rekapitulasi jumlah upload dokumentasi per pegawai dengan breakdown per bulan dan filter tahun.

Stack: Flutter + Riverpod (riverpod_annotation) + GoRouter + Supabase.

---

## Architecture

Arsitektur mengikuti pola yang sudah ada di codebase:

```
Presentation Layer
  ├── Screen / Widget (ConsumerWidget / ConsumerStatefulWidget)
  ├── Provider (AsyncNotifier via riverpod_annotation)
  └── State (AsyncValue<T>)

Domain Layer
  ├── Model (plain Dart class, fromMap factory)
  └── Repository (abstract class)

Data Layer
  └── RepositoryImpl (SupabaseClient)
```

### Alur Data RekapUpload

```
RekapUploadScreen
  └── watches rekapUploadNotifierProvider
        └── calls DokumentasiRepository.getRekapByYear(year)
              └── Supabase query: dokumentasi JOIN users
                    GROUP BY user_id, bulan
              └── aggregate di client: build RekapUploadModel list
```

### Alur Bulk Import

```
KegiatanListScreen (admin)
  └── tombol "Import Proyek" → dialog konfirmasi
        └── calls KegiatanNotifier.bulkImport()
              └── KegiatanRepository.bulkImport(projects)
                    └── Supabase: fetch existing titles
                          → filter out duplicates
                          → insert remaining (upsert on conflict ignore)
              └── returns BulkImportResult(inserted, skipped)
```

---

## Components and Interfaces

### 1. DokumentasiRepository (perubahan)

Tambah method baru `getRekapByYear`:

```dart
abstract class DokumentasiRepository {
  // ... existing methods ...

  /// Ambil semua dokumentasi untuk tahun tertentu, join dengan users.
  /// Digunakan untuk membangun rekap upload per pegawai.
  Future<List<DokumentasiModel>> getByYear(int year);
}
```

`DokumentasiRepositoryImpl.getByYear` mengeksekusi query:

```dart
Future<List<DokumentasiModel>> getByYear(int year) async {
  final data = await _client
      .from('dokumentasi')
      .select('*, users(nama, jabatan, unit_kerja)')
      .gte('tanggal_kegiatan', '$year-01-01')
      .lte('tanggal_kegiatan', '$year-12-31')
      .order('tanggal_kegiatan', ascending: false);
  return (data as List).map((e) => DokumentasiModel.fromMap(e)).toList();
}
```

> **Catatan desain**: Aggregasi dilakukan di client side (bukan SQL GROUP BY) agar tetap menggunakan `DokumentasiModel` yang sudah ada dan menghindari kebutuhan custom RPC Supabase. Untuk skala data yang ada (pegawai ~20-50 orang, dokumentasi per tahun ~beberapa ratus), pendekatan ini cukup efisien.

### 2. KegiatanRepository (perubahan)

Tambah method `bulkImport`:

```dart
abstract class KegiatanRepository {
  // ... existing methods ...

  /// Import banyak kegiatan sekaligus, idempotent berdasarkan judul.
  /// Mengembalikan hasil berupa jumlah yang berhasil diinsert dan yang dilewati.
  Future<BulkImportResult> bulkImport(List<String> judulList, DateTime deadline);
}
```

### 3. Model Baru: BulkImportResult

```dart
// lib/features/kegiatan/domain/bulk_import_result.dart
class BulkImportResult {
  final int inserted;
  final int skipped;

  const BulkImportResult({required this.inserted, required this.skipped});
}
```

### 4. Model Baru: RekapUploadModel

```dart
// lib/features/rekap_upload/domain/rekap_upload_model.dart
class RekapUploadModel {
  final String userId;
  final String nama;
  final String? jabatan;
  final String? unitKerja;
  final int total;
  // Bulan 1-12, value = jumlah upload bulan tersebut
  final Map<int, int> perBulan;

  const RekapUploadModel({
    required this.userId,
    required this.nama,
    this.jabatan,
    this.unitKerja,
    required this.total,
    required this.perBulan,
  });
}
```

### 5. Provider Baru: RekapUploadNotifier

```dart
// lib/features/rekap_upload/presentation/rekap_upload_provider.dart

@riverpod
class RekapUploadNotifier extends _$RekapUploadNotifier {
  int _selectedYear = DateTime.now().year;

  int get selectedYear => _selectedYear;

  @override
  Future<List<RekapUploadModel>> build() async {
    return _fetchRekap(_selectedYear);
  }

  Future<void> changeYear(int year) async {
    _selectedYear = year;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchRekap(year));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchRekap(_selectedYear));
  }

  Future<List<RekapUploadModel>> _fetchRekap(int year) async {
    final docs = await ref
        .read(dokumentasiRepositoryProvider)
        .getByYear(year);
    return _aggregate(docs);
  }

  List<RekapUploadModel> _aggregate(List<DokumentasiModel> docs) {
    final Map<String, _UserAccumulator> acc = {};
    for (final doc in docs) {
      final entry = acc.putIfAbsent(
        doc.userId,
        () => _UserAccumulator(
          userId: doc.userId,
          nama: doc.pegawaiNama ?? '',
          jabatan: doc.pegawaiJabatan,
          unitKerja: doc.pegawaiUnitKerja,
        ),
      );
      entry.total++;
      final bulan = doc.tanggalKegiatan.month;
      entry.perBulan[bulan] = (entry.perBulan[bulan] ?? 0) + 1;
    }
    final result = acc.values
        .map((e) => RekapUploadModel(
              userId: e.userId,
              nama: e.nama,
              jabatan: e.jabatan,
              unitKerja: e.unitKerja,
              total: e.total,
              perBulan: Map.unmodifiable(e.perBulan),
            ))
        .toList();
    result.sort((a, b) => b.total.compareTo(a.total));
    return result;
  }
}
```

### 6. RekapUploadScreen

```dart
// lib/features/rekap_upload/presentation/rekap_upload_screen.dart

class RekapUploadScreen extends ConsumerWidget {
  const RekapUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rekapAsync = ref.watch(rekapUploadNotifierProvider);
    final notifier = ref.read(rekapUploadNotifierProvider.notifier);
    final selectedYear = notifier.selectedYear;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Upload'),
        leading: const AdminMenuButton(),
        actions: [
          const AdminLogoutButton(),
          // Year picker dropdown
          _YearDropdown(
            selectedYear: selectedYear,
            onChanged: (year) => notifier.changeYear(year),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.refresh(),
          ),
        ],
      ),
      body: rekapAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorDisplay(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return const _EmptyRekap();
          }
          final grandTotal = list.fold(0, (sum, r) => sum + r.total);
          return Column(
            children: [
              _GrandTotalBanner(total: grandTotal, year: selectedYear),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => notifier.refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) =>
                        _RekapCard(rekap: list[index], rank: index + 1),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

**Sub-widget `_RekapCard`** menampilkan:

- Rank number + nama pegawai (bold)
- Jabatan dan unit kerja (subtitle)
- Total upload (badge)
- Horizontal scrollable row breakdown per bulan (Jan–Des)

**Sub-widget `_GrandTotalBanner`** menampilkan total keseluruhan upload dan tahun yang dipilih.

**Sub-widget `_YearDropdown`** menampilkan dropdown tahun dari 2024 hingga tahun berjalan.

### 7. Perubahan DokumentasiModel

Tambah field join untuk jabatan dan unit_kerja agar bisa digunakan di rekap:

```dart
class DokumentasiModel {
  // ... existing fields ...
  final String? pegawaiNama;
  final String? pegawaiJabatan;   // NEW
  final String? pegawaiUnitKerja; // NEW

  factory DokumentasiModel.fromMap(Map<String, dynamic> map) {
    final users = map['users'] as Map<String, dynamic>?;
    return DokumentasiModel(
      // ... existing ...
      pegawaiNama: users?['nama'] as String?,
      pegawaiJabatan: users?['jabatan'] as String?,     // NEW
      pegawaiUnitKerja: users?['unit_kerja'] as String?, // NEW
    );
  }
}
```

### 8. Perubahan AdminScaffold

Tambah `_NavItem` baru di `_AdminSidebar`:

```dart
_NavItem(
  icon: Icons.bar_chart_outlined,
  label: 'Rekap Upload',
  route: '/admin/rekap-upload',
  isActive: currentLocation.startsWith('/admin/rekap-upload'),
),
```

Ditempatkan setelah nav item "Dokumentasi" dan sebelum "Import Data".

### 9. Perubahan app_router.dart

Tambah route baru di dalam `ShellRoute` admin:

```dart
GoRoute(
  path: '/admin/rekap-upload',
  builder: (context, state) => const RekapUploadScreen(),
),
```

### 10. Perubahan KegiatanListScreen

Tambah tombol "Import Proyek" di AppBar actions (hanya untuk `isAdmin == true`):

```dart
if (isAdmin)
  IconButton(
    icon: const Icon(Icons.upload_outlined),
    tooltip: 'Import Proyek',
    onPressed: () => _showImportDialog(context, ref),
  ),
```

Method `_showImportDialog` menampilkan `AlertDialog` konfirmasi, lalu memanggil `KegiatanNotifier.bulkImport()` dan menampilkan `SnackBar` dengan hasil.

### 11. Perubahan KegiatanNotifier

Tambah method `bulkImport`:

```dart
Future<BulkImportResult?> bulkImport() async {
  try {
    final deadline = DateTime(2026, 12, 31);
    final result = await ref
        .read(kegiatanRepositoryProvider)
        .bulkImport(_kProyekList, deadline);
    await refresh();
    return result;
  } catch (_) {
    return null;
  }
}
```

Konstanta `_kProyekList` berisi 65 judul proyek (didefinisikan sebagai `const List<String>` di file provider atau file constants terpisah).

---

## Data Models

### RekapUploadModel

| Field       | Type            | Keterangan                                              |
| ----------- | --------------- | ------------------------------------------------------- |
| `userId`    | `String`        | ID user dari tabel `users`                              |
| `nama`      | `String`        | Nama lengkap pegawai                                    |
| `jabatan`   | `String?`       | Jabatan pegawai                                         |
| `unitKerja` | `String?`       | Unit kerja pegawai                                      |
| `total`     | `int`           | Total dokumentasi yang diupload pada tahun yang dipilih |
| `perBulan`  | `Map<int, int>` | Key: bulan (1-12), Value: jumlah upload bulan tersebut  |

### BulkImportResult

| Field      | Type  | Keterangan                                   |
| ---------- | ----- | -------------------------------------------- |
| `inserted` | `int` | Jumlah proyek yang berhasil diinsert         |
| `skipped`  | `int` | Jumlah proyek yang dilewati karena sudah ada |

### DokumentasiModel (perubahan)

Tambah dua field opsional:

| Field              | Type      | Keterangan                                        |
| ------------------ | --------- | ------------------------------------------------- |
| `pegawaiJabatan`   | `String?` | Jabatan pegawai (dari join `users.jabatan`)       |
| `pegawaiUnitKerja` | `String?` | Unit kerja pegawai (dari join `users.unit_kerja`) |

Query yang menggunakan join `users` perlu diupdate dari `users(nama)` menjadi `users(nama, jabatan, unit_kerja)` di `getByYear`. Method `getAll` dan `getByUserId` yang sudah ada tidak perlu diubah (tidak membutuhkan jabatan/unit_kerja).

### Supabase Query untuk getByYear

```sql
SELECT
  dokumentasi.*,
  users.nama,
  users.jabatan,
  users.unit_kerja
FROM dokumentasi
JOIN users ON dokumentasi.user_id = users.id
WHERE tanggal_kegiatan >= '{year}-01-01'
  AND tanggal_kegiatan <= '{year}-12-31'
ORDER BY tanggal_kegiatan DESC
```

Aggregasi `GROUP BY user_id, bulan` dilakukan di Dart (client side) untuk menghindari kebutuhan custom RPC.

### Daftar 65 Proyek (untuk Bulk Import)

```dart
const List<String> kProyekBulkImport = [
  'Updating Direktori Usaha/Perusahaan Ekonomi Lanjutan (Groundcheck SBR)',
  'Pengolahan Peta Wilkerstat 2026',
  'Master File Desa',
  'Data Tunggal Sosial dan Ekonomi Nasional (DTSEN)',
  'Pemutakhiran Data Perkembangan Desa (PODES) 2026',
  'Berbagi Ilmu',
  'Bappenas',
  'Laporan Pemotongan Ternak Bulanan (LPTB)',
  'Pengisian LKE ZI (WBK/WBBM)',
  'Jumat Sehat',
  'Revisi Anggaran',
  'Pendataan Laporan Triwulanan PP/TPI',
  'Program Manajemen Perubahan dan Implementasi RB',
  'Laporan Tahunan Perusahan Budidaya Perikanan (LTB)',
  'Form Rencana Aksi (FRA) Triwulanan',
  'Matriks Peran Hasil (MPH)',
  'Perjanjian Kinerja (PK)',
  'Sakernas Tahun 2026',
  'Rencana Strategis (Renstra)',
  'Rencana Penarikan Dana (RPD)',
  'Back Office System (BOS)',
  'Kompetensi pegawai',
  'Melaksanakan pelayanan Rekomendasi kegiatan Statistik (Romantik) seseuai standar',
  'Survei Harga Kemahalan Konstruksi (SHKK)',
  'Sasaran Kinerja Pegawai/KipApp',
  'Publikasi Kecamatan Dalam Angka',
  'Survei captive power',
  'Publikasi Kabupaten Minahasa Selatan Dalam Angka',
  'Disiplin Pegawai',
  'Survei IBS Tahunan (STPIM)',
  'Survei Harga Konsumen (SHK)',
  'Terlaksananya Survei Harga Perdesaan',
  'Pemutakhiran website',
  'Evaluasi Penyelenggaraan Statistik Sektoral (EPSS)',
  'Survei Kebutuhan Data (SKD)',
  'Sensus Ekonomi 2026',
  'Pembinaan Statistik Sektoral (PSS)',
  'Survei Harga Produsen (SHP, SHPJ, SHPT)',
  'Pemanfaatan Perangkat dan Jaringan TI',
  'Melaksanakan pelayanan metadata statistik sektoral sesuai standar',
  'Konten media sosial yang kreatif dan inovatif',
  'Pemeliharaan Jaringan dan Perangkat TI',
  'Survei Sosial Ekonomi Nasional (SUSENAS) 2026',
  'Desa Cinta Statistik (DESA CANTIK) 2026',
  'Cuti Pegawai',
  'Reward dan Punishment pegawai',
  'Karpeg/Karis/Karsu/Taspen/Tapera',
  'Pemilihan Insan Statistik Teladan',
  'Kesejahteraan Pegawai (Tunjangan Kinerja pegawai, Uang Makan pegawai, Uang Lembur pegawai)',
  'Pemutakhiran data pegawai pada Simpeg dan SIASN',
  'Survei Budaya Organisasi',
  'Pengelolaan LHKPN/SPT',
  'Penyusunan Laporan Kinerja',
  'Survei Harga Perdesaan (HKD dan HD)',
  'Survei Tanaman Pangan/Ubinan',
  'Survei Harga Perdagangan Besar (SHPB)',
  'Survei Kerangka Sampel Area (KSA)',
  'Updating DPP dan DUTL',
  'Survei Perusahaan Perkebunan Bulanan (Sedapp Online)',
  'VN-Hortikultura',
  'Survei Perusahaan Perkebunan (SKB) Tahunan',
  'Statistik Pertanian Tanaman Pangan (SP)',
  'Survei Biaya Hidup (SBH)',
  'Pelayanan Statistik Terpadu',
  'Survei Nasional Literasi dan Inklusi Keuangan (SNLIK)',
];
```

> **Catatan**: List di atas berisi 65 entri. Item "Kesejahteraan Pegawai (Tunjangan Kinerja pegawai, Uang Makan pegawai, Uang Lembur pegawai)" muncul dua kali di sumber HTML — mekanisme idempotent akan menangani duplikat ini secara otomatis.

---

## Correctness Properties

_A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees._

### Property 1: Filter pegawai hanya menampilkan dokumentasi milik pegawai yang dipilih

_For any_ list dokumentasi yang berisi berbagai `userId`, ketika filter `userId` tertentu diterapkan, semua item dalam hasil filter harus memiliki `userId` yang sama dengan filter yang dipilih.

**Validates: Requirements 1.7**

---

### Property 2: Filter proyek hanya menampilkan dokumentasi yang proyeknya mengandung teks filter

_For any_ list dokumentasi dan _any_ string filter proyek yang tidak kosong, semua item dalam hasil filter harus memiliki `proyek` yang mengandung string filter tersebut (case-insensitive).

**Validates: Requirements 1.8**

---

### Property 3: Filter tanggal hanya menampilkan dokumentasi dalam rentang yang dipilih

_For any_ list dokumentasi dan _any_ rentang tanggal `[from, to]`, semua item dalam hasil filter harus memiliki `tanggalKegiatan` yang berada dalam rentang tersebut (inklusif).

**Validates: Requirements 1.9**

---

### Property 4: Reset filter mengembalikan ke state semula (round-trip)

_For any_ kombinasi filter yang diterapkan, setelah reset filter dijalankan, list yang ditampilkan harus identik dengan list sebelum filter diterapkan.

**Validates: Requirements 1.10**

---

### Property 5: Bulk import bersifat idempotent

_For any_ state awal tabel `kegiatan`, menjalankan `bulkImport` dua kali berturut-turut harus menghasilkan state akhir yang sama dengan menjalankannya satu kali — tidak ada duplikat yang dibuat.

**Validates: Requirements 3.5**

---

### Property 6: Semua proyek yang diimport memiliki deadline 31 Desember 2026

_For any_ proyek yang berhasil diinsert melalui `bulkImport`, deadline-nya harus sama dengan `DateTime(2026, 12, 31)`.

**Validates: Requirements 3.4**

---

### Property 7: Grand total rekap sama dengan jumlah semua individual total

_For any_ list `RekapUploadModel`, grand total (sum dari semua `rekap.total`) harus sama dengan jumlah seluruh dokumentasi yang digunakan untuk membangun list tersebut.

**Validates: Requirements 4.7**

---

### Property 8: Breakdown per bulan konsisten dengan total

_For any_ `RekapUploadModel`, jumlah nilai dalam `perBulan.values` harus sama dengan `total`.

**Validates: Requirements 4.4**

---

### Property 9: Daftar rekap diurutkan descending berdasarkan total

_For any_ list `RekapUploadModel` yang dihasilkan oleh `_aggregate`, untuk setiap pasangan item berurutan `(list[i], list[i+1])`, harus berlaku `list[i].total >= list[i+1].total`.

**Validates: Requirements 4.8**

---

### Property 10: Setiap card rekap menampilkan nama, jabatan, dan unit kerja

_For any_ `RekapUploadModel` dengan `nama`, `jabatan`, dan `unitKerja` yang terisi, widget `_RekapCard` yang dirender harus mengandung teks ketiga field tersebut.

**Validates: Requirements 4.12**

---

## Error Handling

### Bulk Import

| Skenario                                  | Penanganan                                                                                                                        |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Supabase error saat fetch existing titles | `AppException` dilempar, ditangkap di `KegiatanNotifier.bulkImport()`, dikembalikan sebagai `null`, UI menampilkan SnackBar error |
| Supabase error saat insert                | `AppException` dilempar, ditangkap di notifier, UI menampilkan SnackBar error                                                     |
| Semua proyek sudah ada (0 inserted)       | Bukan error — `BulkImportResult(inserted: 0, skipped: 65)` dikembalikan, UI menampilkan notifikasi informatif                     |

### RekapUploadScreen

| Skenario                                | Penanganan                                                                |
| --------------------------------------- | ------------------------------------------------------------------------- |
| Supabase error saat `getByYear`         | `AsyncValue.error` — `ErrorDisplay` widget ditampilkan dengan pesan error |
| Tidak ada data untuk tahun yang dipilih | `AsyncValue.data([])` — `_EmptyRekap` widget ditampilkan                  |
| User tidak terautentikasi               | Ditangani oleh GoRouter redirect ke `/login` sebelum mencapai screen ini  |

### DokumentasiScreen / RiwayatDokumentasiScreen

Tidak ada perubahan pada error handling yang sudah ada — kedua screen sudah menggunakan `ErrorDisplay` widget untuk menampilkan error dari provider.

---

## Testing Strategy

### Unit Tests

Fokus pada logika pure yang tidak bergantung pada UI atau Supabase:

1. **`RekapUploadNotifier._aggregate`** — Test dengan berbagai kombinasi list `DokumentasiModel`:
   - List kosong → hasil kosong
   - Satu user, beberapa dokumentasi di bulan berbeda → `perBulan` benar
   - Beberapa user → diurutkan descending berdasarkan total
   - Dokumentasi dari tahun berbeda tidak masuk (sudah difilter di query)

2. **Filter logic di `DokumentasiScreen`** — Test fungsi filter client-side:
   - Filter by `userId`
   - Filter by `proyek` (case-insensitive contains)
   - Filter by date range
   - Kombinasi filter

3. **`KegiatanRepositoryImpl.bulkImport`** — Test dengan mock Supabase:
   - Semua proyek baru → semua diinsert
   - Beberapa proyek sudah ada → hanya yang baru diinsert
   - Semua proyek sudah ada → tidak ada yang diinsert
   - Idempotency: run dua kali → hasil sama

### Property-Based Tests

Menggunakan library **`fast_check`** (Dart) atau **`glados`** (Dart PBT library). Minimum 100 iterasi per property.

Setiap property test diberi tag komentar:

```dart
// Feature: dokumentasi-rekap-enhancement, Property N: <property_text>
```

**Property tests yang akan diimplementasikan:**

- **Property 2**: Generate random list `DokumentasiModel` dengan berbagai `proyek` dan random filter string → verifikasi semua hasil mengandung filter string.
- **Property 3**: Generate random list `DokumentasiModel` dengan berbagai `tanggalKegiatan` dan random date range → verifikasi semua hasil dalam rentang.
- **Property 5**: Generate random initial state kegiatan, run `bulkImport` dua kali → verifikasi count sama.
- **Property 7 & 8**: Generate random list `DokumentasiModel`, run `_aggregate` → verifikasi grand total dan per-bulan consistency.
- **Property 9**: Generate random list `DokumentasiModel`, run `_aggregate` → verifikasi urutan descending.

### Widget Tests

- `DokumentasiScreen` menggunakan `adminDokumentasiNotifierProvider` (bukan `myDokumentasiNotifierProvider`)
- `RiwayatDokumentasiScreen` menggunakan `myDokumentasiNotifierProvider`
- `RekapUploadScreen` menampilkan `LoadingShimmer` saat loading, `_EmptyRekap` saat data kosong
- `KegiatanListScreen` menampilkan tombol Import Proyek hanya saat `isAdmin == true`
- `AdminScaffold` sidebar berisi nav item "Rekap Upload"

### Integration Tests (Manual / Staging)

- Bulk import 65 proyek ke Supabase staging → verifikasi count di tabel `kegiatan`
- Jalankan bulk import kedua kali → verifikasi tidak ada duplikat
- Buka `RekapUploadScreen` dengan data nyata → verifikasi total sesuai dengan count di Supabase
- Filter tahun di `RekapUploadScreen` → verifikasi data berubah sesuai tahun
