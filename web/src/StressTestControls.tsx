import { useState } from 'react'
import './stressTestBridge'

const TEST_PREFIX = 'ZZTest'
const COUNTS = [100, 250, 500, 1000] as const

export default function StressTestControls() {
  const [status, setStatus] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const handleGenerate = async (count: number) => {
    setLoading(true)
    setStatus('Generating contacts...')
    try {
      const result = await window.webkit!.messageHandlers.generateContacts.postMessage({
        count,
        prefix: TEST_PREFIX,
      })
      setStatus(`Created ${result.created} contacts in ${result.timing.totalMs}ms`)
    } catch (e) {
      setStatus(`Error: ${e}`)
    }
    setLoading(false)
  }

  const handleCleanup = async () => {
    setLoading(true)
    setStatus('Cleaning up contacts...')
    try {
      const result = await window.webkit!.messageHandlers.cleanupContacts.postMessage({
        prefix: TEST_PREFIX,
      })
      setStatus(`Deleted ${result.deleted} contacts in ${result.timing.totalMs}ms`)
    } catch (e) {
      setStatus(`Error: ${e}`)
    }
    setLoading(false)
  }

  return (
    <>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12, maxWidth: 300 }}>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {COUNTS.map((count) => (
            <button
              key={count}
              onClick={() => handleGenerate(count)}
              disabled={loading}
              style={{
                padding: '12px 16px', fontSize: 16, borderRadius: 8,
                border: 'none', background: '#34c759', color: 'white',
                cursor: loading ? 'not-allowed' : 'pointer', opacity: loading ? 0.6 : 1,
                flex: '1 1 auto',
              }}
            >
              +{count}
            </button>
          ))}
        </div>
        <button
          onClick={handleCleanup}
          disabled={loading}
          style={{
            padding: '12px 16px', fontSize: 16, borderRadius: 8,
            border: 'none', background: '#ff3b30', color: 'white',
            cursor: loading ? 'not-allowed' : 'pointer', opacity: loading ? 0.6 : 1,
          }}
        >
          Cleanup Test Contacts
        </button>
        <p style={{ fontSize: 13, color: '#888', margin: 0 }}>
          Test contacts are prefixed with "{TEST_PREFIX}" for easy identification.
        </p>
      </div>

      {status && (
        <div style={{
          marginTop: 16, padding: 12, borderRadius: 8,
          background: '#f0f0f0', fontSize: 14,
        }}>
          {status}
        </div>
      )}
    </>
  )
}
