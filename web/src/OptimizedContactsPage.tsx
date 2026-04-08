import { useCallback, useEffect, useRef, useState } from 'react'
import { Link } from 'react-router'
import { Input } from '@/components/ui/input'
import { Skeleton } from '@/components/ui/skeleton'
import type { Contact, Timing } from './bridge'
import type { SearchContactsResponse } from './optimizedBridge'
import './ContactsPage.css'

const PAGE_SIZE = 100
const DEBOUNCE_MS = 300

function OptimizedContactsPage() {
  const [contacts, setContacts] = useState<Contact[]>([])
  const [hasMore, setHasMore] = useState(true)
  const [timing, setTiming] = useState<Timing | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)
  const [query, setQuery] = useState('')
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(null)
  const sentinelRef = useRef<HTMLDivElement>(null)
  const currentQueryRef = useRef('')
  const initialLoadRef = useRef(true)

  const fetchPage = useCallback(async (searchQuery: string, offset: number) => {
    const bridgeStart = performance.now()
    const result: SearchContactsResponse = await window.webkit!.messageHandlers.searchContacts.postMessage({
      query: searchQuery || undefined,
      offset,
      limit: PAGE_SIZE,
    })
    const bridgeMs = Math.round((performance.now() - bridgeStart) * 10) / 10
    return { result, bridgeMs }
  }, [])

  // Initial load + search changes
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)

    debounceRef.current = setTimeout(async () => {
      currentQueryRef.current = query
      setLoading(true)
      setContacts([])

      const { result, bridgeMs } = await fetchPage(query, 0)
      const bridgeOverheadMs = Math.round((bridgeMs - result.timing.totalNativeMs) * 10) / 10
      const stateStart = performance.now()
      setContacts(result.contacts)
      setHasMore(result.hasMore)
      setLoading(false)

      requestAnimationFrame(() => {
        const renderMs = Math.round((performance.now() - stateStart) * 10) / 10
        setTiming({ ...result.timing, bridgeMs, bridgeOverheadMs, renderMs })
      })
    }, initialLoadRef.current ? 0 : DEBOUNCE_MS)
    initialLoadRef.current = false

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current)
    }
  }, [query, fetchPage])

  // Infinite scroll observer
  useEffect(() => {
    const sentinel = sentinelRef.current
    if (!sentinel) return

    const observer = new IntersectionObserver(
      async (entries) => {
        const entry = entries[0]
        if (!entry.isIntersecting) return
        if (loadingMore || loading) return
        if (!hasMore) return

        setLoadingMore(true)
        const { result } = await fetchPage(currentQueryRef.current, contacts.length)
        setContacts((prev) => [...prev, ...result.contacts])
        setHasMore(result.hasMore)
        setLoadingMore(false)
      },
      { rootMargin: '200px' }
    )

    observer.observe(sentinel)
    return () => observer.disconnect()
  }, [contacts.length, hasMore, loading, loadingMore, fetchPage])

  return (
    <div className="container">
      <div className="timing">
        {timing ? (
          <>
            <div>Native auth: {timing.authMs}ms</div>
            <div>Native fetch: {timing.fetchMs}ms</div>
            <div>Native total: {timing.totalNativeMs}ms</div>
            <div>Bridge serialization: {timing.bridgeOverheadMs}ms</div>
            <div>Bridge round-trip: {timing.bridgeMs}ms</div>
            <div>React render: {timing.renderMs}ms</div>
            <div>Showing {contacts.length} contacts</div>
          </>
        ) : (
          <div>Loading…</div>
        )}
      </div>
      <Input
        placeholder="Search contacts…"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        className="mb-3"
      />
      <ul className="contact-list">
        {loading
          ? Array.from({ length: 8 }, (_, i) => (
              <li key={i} className="contact-item">
                <Skeleton className="h-10 w-10 rounded-full flex-shrink-0" />
                <div className="contact-info">
                  <Skeleton className="h-4 w-32" />
                  <Skeleton className="h-3 w-24 mt-1" />
                </div>
              </li>
            ))
          : contacts.map((c, i) => (
              <li key={i}>
                <Link to={`/contacts-optimized/${i}`} state={{ contact: c }} className="contact-item contact-link">
                  <div className="avatar">
                    {(c.givenName[0] || '') + (c.familyName[0] || '')}
                  </div>
                  <div className="contact-info">
                    <div className="contact-name">{c.givenName} {c.familyName}</div>
                    {c.phoneNumbers.map((p, j) => (
                      <div key={j} className="contact-phone">{p}</div>
                    ))}
                  </div>
                </Link>
              </li>
            ))}
      </ul>
      <div ref={sentinelRef} style={{ height: 1 }} />
      {loadingMore && (
        <div style={{ textAlign: 'center', padding: 16, color: '#888' }}>
          Loading more…
        </div>
      )}
    </div>
  )
}

export default OptimizedContactsPage
