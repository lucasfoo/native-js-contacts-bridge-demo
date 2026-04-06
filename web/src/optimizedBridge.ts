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
