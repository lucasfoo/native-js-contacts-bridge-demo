export interface Contact {
  givenName: string
  familyName: string
  phoneNumbers: string[]
}

export interface Timing {
  authMs: number
  fetchMs: number
  totalNativeMs: number
  bridgeMs?: number
  renderMs?: number
}

export interface GetContactsResponse {
  contacts: Contact[]
  timing: Omit<Timing, 'bridgeMs' | 'renderMs'>
}

declare global {
  interface Window {
    webkit?: {
      messageHandlers: {
        getContacts: {
          postMessage: (body: unknown) => Promise<GetContactsResponse>
        }
        searchContacts: {
          postMessage: (body: import('./optimizedBridge').SearchContactsRequest) => Promise<import('./optimizedBridge').SearchContactsResponse>
        }
        generateContacts: {
          postMessage: (body: { count: number; prefix: string }) => Promise<import('./stressTestBridge').GenerateResponse>
        }
        cleanupContacts: {
          postMessage: (body: { prefix: string }) => Promise<import('./stressTestBridge').CleanupResponse>
        }
      }
    }
  }
}
