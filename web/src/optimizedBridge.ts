import type { Contact } from './bridge'

export interface SearchContactsRequest {
  query?: string
  offset: number
  limit: number
}

export interface SearchContactsResponse {
  contacts: Contact[]
  hasMore: boolean
  timing: {
    authMs: number
    fetchMs: number
    totalNativeMs: number
  }
}
