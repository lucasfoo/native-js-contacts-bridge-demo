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
      }
    }
  }
}
