import { defineConfig } from "vitest/config"

export default defineConfig({
  test: {
    // Semua file test memakai satu database yang sama, jadi jalankan berurutan.
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 30_000
  }
})
