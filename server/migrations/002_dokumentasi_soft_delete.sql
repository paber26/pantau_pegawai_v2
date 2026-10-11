-- Hapus dokumentasi oleh pegawai hanya menyembunyikan data (soft delete).
-- Admin tetap bisa melihat yang dihapus dan mengembalikannya.
ALTER TABLE dokumentasi
  ADD COLUMN deleted_at TIMESTAMPTZ,
  ADD COLUMN deleted_by UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX idx_dokumentasi_deleted_at ON dokumentasi(deleted_at DESC) WHERE deleted_at IS NOT NULL;
