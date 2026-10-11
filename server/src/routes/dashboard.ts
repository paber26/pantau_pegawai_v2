import type { FastifyInstance } from "fastify"

import type { AppContext } from "../app.js"

export async function dashboardRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db, auth, config } = ctx

  /**
   * Statistik dashboard admin, dihitung dengan COUNT di database (tidak lagi
   * terbatas 1000 baris seperti saat dihitung di aplikasi).
   *
   * "Belum upload" = pegawai yang belum punya dokumentasi dengan tanggal
   * kegiatan hari ini menurut zona waktu kantor (APP_TIMEZONE, default WITA).
   */
  app.get("/api/dashboard/stats", { preHandler: auth.requireAdmin }, async () => {
    const { rows } = await db.query(
      `WITH today AS (SELECT (NOW() AT TIME ZONE $1)::date AS d)
       SELECT
         (SELECT COUNT(*) FROM users WHERE role = 'pegawai')::int AS total_pegawai,
         (SELECT COUNT(*) FROM kegiatan)::int AS jumlah_proyek,
         (SELECT COUNT(*) FROM dokumentasi WHERE deleted_at IS NULL)::int AS total_dokumentasi,
         (SELECT COUNT(*) FROM users u
           WHERE u.role = 'pegawai'
             AND NOT EXISTS (
               SELECT 1 FROM dokumentasi d, today
                WHERE d.user_id = u.id AND d.tanggal_kegiatan = today.d AND d.deleted_at IS NULL
             ))::int AS pegawai_belum_upload,
         (SELECT d FROM today) AS tanggal`,
      [config.appTimezone]
    )
    return rows[0]
  })
}
