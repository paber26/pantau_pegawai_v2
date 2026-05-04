# Tahap 5 — Fitur Authentication

## 5.1 Alur Login

```
User input email + password
    ↓
supabase.auth.signInWithPassword()
    ↓
Fetch profil dari tabel public.users
    ↓
Simpan AppAuthUser (id, nama, email, role)
    ↓
go_router redirect berdasarkan role:
  - admin  → /admin/dashboard
  - pegawai → /pegawai/dokumentasi
```

## 5.2 Model AppAuthUser

Nama class menggunakan prefix `App` untuk menghindari konflik dengan `AuthUser` dari package `supabase_flutter`:

```dart
// lib/features/auth/domain/auth_state.dart
class AppAuthUser {
  final String id;
  final String nama;
  final String email;
  final String? jabatan;
  final String? unitKerja;
  final String role;

  bool get isAdmin => role == 'admin';
}
```

## 5.3 Auth Provider (Riverpod)

```dart
// Stream auth state changes
@riverpod
Stream<AppAuthUser?> authState(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}

// Notifier untuk login/logout
@riverpod
class AuthNotifier extends _$AuthNotifier {
  Future<void> login({required String email, required String password}) async { ... }
  Future<void> logout() async { ... }
}
```

## 5.4 Role-Based Redirect di Router

```dart
redirect: (context, state) {
  final isLoggedIn = authState.valueOrNull != null;
  final isLoginPage = state.matchedLocation == '/login';

  if (!isLoggedIn && !isLoginPage) return '/login';
  if (isLoggedIn && isLoginPage) {
    final role = authState.valueOrNull?.role ?? 'pegawai';
    return role == 'admin' ? '/admin/dashboard' : '/pegawai/dokumentasi';
  }
  return null;
},
```

## 5.5 Masalah yang Ditemui

### Ambiguous import: AuthUser

**Masalah:** `supabase_flutter` mengekspor class `AuthUser` yang bentrok dengan class kita.

**Solusi:** Rename class kita menjadi `AppAuthUser`, dan di file yang import supabase gunakan:

```dart
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
```

### Ambiguous import: AuthException & StorageException

**Masalah:** Sama seperti di atas, `supabase_flutter` mengekspor `AuthException` dan `StorageException`.

**Solusi:**

```dart
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, StorageException;
```

## 5.6 Logout

```dart
await ref.read(authNotifierProvider.notifier).logout();
context.go('/login');
```
