import pg from "pg"

// DATE dikembalikan apa adanya ("yyyy-MM-dd"), bukan objek Date JS yang akan
// diserialisasi jadi timestamp UTC (mis. "2026-05-03T16:00:00.000Z") dan
// membuat tanggal bergeser satu hari di aplikasi.
pg.types.setTypeParser(pg.types.builtins.DATE, (value) => value)

export type Db = pg.Pool
export type DbClient = pg.PoolClient
/** Pool, client dari pool, atau client tunggal. */
export type Queryable = pg.Pool | pg.ClientBase

export function createPool(connectionString: string): pg.Pool {
  return new pg.Pool({ connectionString, max: 10 })
}

/** Jalankan [fn] di dalam satu transaksi; rollback otomatis bila error. */
export async function withTransaction<T>(db: Db, fn: (client: DbClient) => Promise<T>): Promise<T> {
  const client = await db.connect()
  try {
    await client.query("BEGIN")
    const result = await fn(client)
    await client.query("COMMIT")
    return result
  } catch (err) {
    await client.query("ROLLBACK")
    throw err
  } finally {
    client.release()
  }
}
