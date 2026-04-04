export interface GenerateResponse {
  created: number
  timing: { generateMs: number; totalMs: number }
}

export interface CleanupResponse {
  deleted: number
  timing: { totalMs: number }
}

declare global {
  interface Window {
    webkit?: {
      messageHandlers: {
        generateContacts: {
          postMessage: (body: { count: number; prefix: string }) => Promise<GenerateResponse>
        }
        cleanupContacts: {
          postMessage: (body: { prefix: string }) => Promise<CleanupResponse>
        }
      }
    }
  }
}
