/** Potongan JSON schema yang dipakai bersama oleh beberapa route. */

export const uuid = { type: "string", format: "uuid" } as const

/** Tanggal "yyyy-MM-dd". */
export const date = { type: "string", pattern: "^\\d{4}-\\d{2}-\\d{2}$" } as const

export const idParams = {
  type: "object",
  required: ["id"],
  properties: { id: uuid }
} as const
