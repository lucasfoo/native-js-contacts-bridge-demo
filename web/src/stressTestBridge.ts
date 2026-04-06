export interface GenerateResponse {
  created: number
  timing: { generateMs: number; totalMs: number }
}

export interface CleanupResponse {
  deleted: number
  timing: { totalMs: number }
}
