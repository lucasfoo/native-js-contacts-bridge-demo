import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router'
import { Input } from '@/components/ui/input'
import { Skeleton } from '@/components/ui/skeleton'
import type { Contact, Timing } from './bridge'
import './ContactsPage.css'

function ContactsPage() {
  const [contacts, setContacts] = useState<Contact[]>([])
  const [timing, setTiming] = useState<Timing | null>(null)
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('')

  const { filteredContacts, filterMs } = useMemo(() => {
    const start = performance.now()
    let result: Contact[]
    if (!filter) {
      result = contacts
    } else {
      const q = filter.toLowerCase()
      const qDigits = q.replace(/\D/g, '')
      result = contacts.filter(
        (c) =>
          c.givenName.toLowerCase().includes(q) ||
          c.familyName.toLowerCase().includes(q) ||
          (qDigits && c.phoneNumbers.some((p) => p.replace(/\D/g, '').includes(qDigits))) ||
          c.phoneNumbers.some((p) => p.toLowerCase().includes(q))
      )
    }
    const ms = Math.round((performance.now() - start) * 100) / 100
    return { filteredContacts: result, filterMs: ms }
  }, [contacts, filter])

  useEffect(() => {
    const bridgeStart = performance.now()
    window.webkit!.messageHandlers.getContacts.postMessage("fetch").then((result) => {
      const bridgeMs = Math.round((performance.now() - bridgeStart) * 10) / 10
      setContacts(result.contacts)
      setLoading(false)
      requestAnimationFrame(() => {
        const renderMs = Math.round((performance.now() - bridgeStart - bridgeMs) * 10) / 10
        setTiming({ ...result.timing, bridgeMs, renderMs })
      })
    })
  }, [])

  return (
    <div className="container">
      <div className="timing">
        {timing ? (
          <>
            <div>Native auth: {timing.authMs}ms</div>
            <div>Native fetch: {timing.fetchMs}ms</div>
            <div>Native total: {timing.totalNativeMs}ms</div>
            <div>Bridge round-trip: {timing.bridgeMs}ms</div>
            <div>React render: {timing.renderMs}ms</div>
            <div>{contacts.length} contacts</div>
            {filter && (
              <>
                <div>Filter: {filterMs}ms ({filteredContacts.length}/{contacts.length} shown)</div>
              </>
            )}
          </>
        ) : (
          <div>Loading…</div>
        )}
      </div>
      <Input
        placeholder="Filter contacts…"
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
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
          : filteredContacts.map((c, i) => (
              <li key={i}>
                <Link to={`/contacts/${i}`} state={{ contact: c }} className="contact-item contact-link">
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
    </div>
  )
}

export default ContactsPage
