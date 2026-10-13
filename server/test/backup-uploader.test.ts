import { mkdtemp, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"

import type { FastifyBaseLogger } from "fastify"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { BACKUP_DRIVE_FOLDER, scheduleBackupUploads, uploadPendingBackups } from "../src/backup-uploader.js"
import { FakeDrive } from "./helpers.js"

let dir: string

beforeEach(async () => {
  dir = await mkdtemp(join(tmpdir(), "pantau-backup-"))
})

afterEach(async () => {
  await rm(dir, { recursive: true, force: true })
})

const uploadedNames = (drive: FakeDrive) => [...drive.files.values()].map((f) => f.filename)

describe("uploadPendingBackups", () => {
  it("mengunggah backup yang belum ada di Drive, tanpa link publik", async () => {
    await writeFile(join(dir, "pantau_20261011_020000.dump"), "dump-11")
    await writeFile(join(dir, "pantau_20261012_020000.dump"), "dump-12")
    await writeFile(join(dir, "pantau_20261013_020000.dump.tmp"), "masih ditulis")
    await writeFile(join(dir, "catatan.txt"), "bukan backup")
    const drive = new FakeDrive()
    await drive.uploadFile({
      bytes: Buffer.from("dump-11"),
      filename: "pantau_20261011_020000.dump",
      mimeType: "application/octet-stream",
      folderPath: [BACKUP_DRIVE_FOLDER]
    })

    const result = await uploadPendingBackups(drive, dir)

    expect(result).toEqual({ uploaded: ["pantau_20261012_020000.dump"], failed: [] })
    const file = [...drive.files.values()].find((f) => f.filename === "pantau_20261012_020000.dump")
    expect(file).toMatchObject({
      folderPath: [BACKUP_DRIVE_FOLDER],
      mimeType: "application/octet-stream",
      shareWithLink: false
    })
    expect(file?.bytes.toString()).toBe("dump-12")

    // Berikutnya tidak ada yang diunggah ulang.
    expect(await uploadPendingBackups(drive, dir)).toEqual({ uploaded: [], failed: [] })
    expect(uploadedNames(drive)).toHaveLength(2)
  })

  it("file bernama sama di folder lain tidak dianggap sudah diunggah", async () => {
    await writeFile(join(dir, "pantau_20261012_020000.dump"), "dump")
    const drive = new FakeDrive()
    await drive.uploadFile({
      bytes: Buffer.from("lain"),
      filename: "pantau_20261012_020000.dump",
      mimeType: "application/octet-stream",
      folderPath: ["Budi Santoso"]
    })

    expect((await uploadPendingBackups(drive, dir)).uploaded).toEqual(["pantau_20261012_020000.dump"])
  })

  it("upload gagal dicatat tanpa menghentikan file lain, lalu diulang berikutnya", async () => {
    await writeFile(join(dir, "pantau_20261011_020000.dump"), "a")
    await writeFile(join(dir, "pantau_20261012_020000.dump"), "b")
    const drive = new FakeDrive()
    drive.uploadError = new Error("Drive menolak")

    const gagal = await uploadPendingBackups(drive, dir)
    expect(gagal.uploaded).toEqual([])
    expect(gagal.failed.map((f) => f.name)).toEqual(["pantau_20261011_020000.dump", "pantau_20261012_020000.dump"])

    drive.uploadError = null
    expect((await uploadPendingBackups(drive, dir)).uploaded).toEqual([
      "pantau_20261011_020000.dump",
      "pantau_20261012_020000.dump"
    ])
  })

  it("folder backup kosong: Drive tidak dihubungi", async () => {
    const drive = new FakeDrive()
    const list = vi.spyOn(drive, "listFileNames")

    expect(await uploadPendingBackups(drive, dir)).toEqual({ uploaded: [], failed: [] })
    expect(list).not.toHaveBeenCalled()
  })
})

describe("scheduleBackupUploads", () => {
  it("menjalankan pengecekan dan mencatat file yang diunggah", async () => {
    await writeFile(join(dir, "pantau_20261012_020000.dump"), "dump")
    const drive = new FakeDrive()
    const log = { info: vi.fn(), error: vi.fn() }

    const stop = scheduleBackupUploads(drive, dir, log as unknown as FastifyBaseLogger, {
      firstDelayMs: 0,
      intervalMs: 60_000
    })
    try {
      await vi.waitFor(() => expect(log.info).toHaveBeenCalledWith(expect.stringContaining("pantau_20261012_020000.dump")))
    } finally {
      stop()
    }
    expect(uploadedNames(drive)).toEqual(["pantau_20261012_020000.dump"])
    expect(log.error).not.toHaveBeenCalled()
  })

  it("folder backup tidak ada → error di-log, tidak melempar", async () => {
    const log = { info: vi.fn(), error: vi.fn() }

    const stop = scheduleBackupUploads(new FakeDrive(), join(dir, "tidak-ada"), log as unknown as FastifyBaseLogger, {
      firstDelayMs: 0
    })
    try {
      await vi.waitFor(() => expect(log.error).toHaveBeenCalledOnce())
    } finally {
      stop()
    }
  })
})
