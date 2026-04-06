import type { Contact } from './bridge'

export interface SearchContactsRequest {
  query?: string
  offset: number
  limit: number
}

export interface SearchContactsResponse {
  contacts: Contact[]
  total: number
  timing: {
    authMs: number
    fetchMs: number
    totalNativeMs: number
  }
}

declare global {
  interface Window {
    webkit?: {
      messageHandlers: {
        getContacts: {
          postMessage: (body: unknown) => Promise<import('./bridge').GetContactsResponse>
        }
        searchContacts: {
          postMessage: (body: SearchContactsRequest) => Promise<SearchContactsResponse>
        }
      }
    }
  }
}
