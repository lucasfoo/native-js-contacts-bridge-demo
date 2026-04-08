# Native-JS Contacts Bridge

A guide to building a performant contacts viewer in a WKWebView-based iOS app. This project demonstrates two approaches — a naive "fetch everything" implementation and an optimized version with pagination, native search, and infinite scroll — so you can see exactly where performance breaks down and how to fix it.

## Table of Contents

- [How the Bridge Works](#how-the-bridge-works)
- [Step 1: The Naive Implementation](#step-1-the-naive-implementation)
  - [Swift: WKWebView Setup](#swift-wkwebview-setup)
  - [Swift: Message Handler](#swift-message-handler)
  - [Swift: Contact Fetching](#swift-contact-fetching)
  - [TypeScript: Bridge Types](#typescript-bridge-types)
  - [React: Displaying Contacts](#react-displaying-contacts)
- [Where the Naive Version Falls Down](#where-the-naive-version-falls-down)
- [Step 2: Enhancements](#step-2-enhancements)
  - [1. Pagination with Early Stopping](#1-pagination-with-early-stopping)
  - [2. Native Search via Predicates](#2-native-search-via-predicates)
  - [3. Infinite Scroll](#3-infinite-scroll)
  - [4. Search Debouncing](#4-search-debouncing)
  - [5. Off-Main-Thread Contact Access](#5-off-main-thread-contact-access)
  - [6. Performance Instrumentation](#6-performance-instrumentation)

---

## How the Bridge Works

iOS WKWebView provides `WKScriptMessageHandlerWithReply`, which gives you async request/response communication between JavaScript and Swift:

1. **JS calls** `window.webkit.messageHandlers.<name>.postMessage(payload)` — this returns a `Promise`
2. **Swift receives** the message, does work, and returns a `(result, error)` tuple
3. **JS gets** the resolved promise with the result (or a rejection with the error)

This is the foundation for everything below.

---

## Step 1: The Naive Implementation

### Swift: WKWebView Setup

Create a `UIViewRepresentable` that configures a WKWebView with message handlers:

```swift
struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Required for loading bundled web app from file:// URLs
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // Register each message handler by name
        let handler = context.coordinator.handler
        for name in handler.allHandlerNames {
            config.userContentController.addScriptMessageHandler(
                handler, contentWorld: .page, name: name
            )
        }

        let webView = WKWebView(frame: .zero, configuration: config)

        // Load bundled web app (no server needed)
        if let indexURL = Bundle.main.url(
            forResource: "index", withExtension: "html", subdirectory: "WebApp"
        ) {
            let webAppDir = indexURL.deletingLastPathComponent()
            webView.loadFileURL(indexURL, allowingReadAccessTo: webAppDir)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator {
        let handler: WebViewMessageHandler
        init() {
            handler = WebViewMessageHandler()
            handler.addDelegate(ContactsMessageDelegate())
        }
    }
}
```

Key points:
- `contentWorld: .page` means the handler is accessible from the page's JS context
- The web app is bundled into the iOS project (build with Vite, copy `dist/` into `WebApp/`) and loaded via `loadFileURL` — no dev server required at runtime

### Swift: Message Handler

Use a delegate pattern to route messages by name:

```swift
protocol MessageHandlerDelegate: AnyObject {
    func registeredHandlerNames() -> [String]
    func handleMessage(name: String, body: Any) async -> (Any?, String?)
}

class WebViewMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    private var delegates: [String: MessageHandlerDelegate] = [:]

    func addDelegate(_ delegate: MessageHandlerDelegate) {
        for name in delegate.registeredHandlerNames() {
            delegates[name] = delegate
        }
    }

    var allHandlerNames: [String] { Array(delegates.keys) }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) async -> (Any?, String?) {
        guard let delegate = delegates[message.name] else {
            return (nil, "Unknown handler: \(message.name)")
        }
        return await delegate.handleMessage(name: message.name, body: message.body)
    }
}
```

The return type `(Any?, String?)` is `(result, error)`. Return data in the first slot and `nil` for the error on success, or `nil` and an error string on failure.

Then implement a delegate for contacts:

```swift
class ContactsMessageDelegate: MessageHandlerDelegate {
    private let service = ContactsService()

    func registeredHandlerNames() -> [String] { ["getContacts"] }

    func handleMessage(name: String, body: Any) async -> (Any?, String?) {
        let totalStart = CFAbsoluteTimeGetCurrent()
        let (granted, authMs) = await service.requestAccess()
        guard granted else { return (nil, "Contacts access denied") }

        do {
            let (contacts, fetchMs) = try await service.fetchAll()
            let totalMs = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000
            return ([
                "contacts": contacts,
                "timing": [
                    "authMs": round(authMs * 10) / 10,
                    "fetchMs": round(fetchMs * 10) / 10,
                    "totalNativeMs": round(totalMs * 10) / 10,
                ]
            ], nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }
}
```

### Swift: Contact Fetching

The naive version fetches all contacts in one pass:

```swift
class ContactsService {
    func requestAccess() async -> (granted: Bool, authMs: Double) {
        let store = CNContactStore()
        let authStart = CFAbsoluteTimeGetCurrent()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            let authMs = (CFAbsoluteTimeGetCurrent() - authStart) * 1000
            return (granted, authMs)
        } catch {
            let authMs = (CFAbsoluteTimeGetCurrent() - authStart) * 1000
            return (false, authMs)
        }
    }

    func fetchAll() async throws -> (contacts: [[String: Any]], fetchMs: Double) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let store = CNContactStore()
                    let fetchStart = CFAbsoluteTimeGetCurrent()
                    let keys: [CNKeyDescriptor] = [
                        CNContactGivenNameKey as CNKeyDescriptor,
                        CNContactFamilyNameKey as CNKeyDescriptor,
                        CNContactPhoneNumbersKey as CNKeyDescriptor,
                    ]
                    let request = CNContactFetchRequest(keysToFetch: keys)
                    var contacts: [[String: Any]] = []

                    try store.enumerateContacts(with: request) { contact, _ in
                        contacts.append([
                            "givenName": contact.givenName,
                            "familyName": contact.familyName,
                            "phoneNumbers": contact.phoneNumbers.map {
                                $0.value.stringValue
                            },
                        ])
                    }

                    let fetchMs = (CFAbsoluteTimeGetCurrent() - fetchStart) * 1000
                    continuation.resume(returning: (contacts, fetchMs))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

### TypeScript: Bridge Types

Declare the bridge interface so TypeScript knows what `window.webkit` provides:

```typescript
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
  bridgeOverheadMs?: number
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
```

### React: Displaying Contacts

The naive page fetches all contacts on mount, then filters client-side:

```tsx
function ContactsPage() {
  const [contacts, setContacts] = useState<Contact[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('')

  // Client-side filter with memoization
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
          (qDigits && c.phoneNumbers.some((p) => p.replace(/\D/g, '').includes(qDigits)))
      )
    }
    const ms = Math.round((performance.now() - start) * 100) / 100
    return { filteredContacts: result, filterMs: ms }
  }, [contacts, filter])

  // Fetch all contacts on mount
  useEffect(() => {
    window.webkit!.messageHandlers.getContacts.postMessage('fetch').then((result) => {
      setContacts(result.contacts)
      setLoading(false)
    })
  }, [])

  return (
    <div>
      <input
        placeholder="Filter contacts..."
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
      />
      <ul>
        {filteredContacts.map((c, i) => (
          <li key={i}>
            {c.givenName} {c.familyName}
            {c.phoneNumbers.map((p, j) => <div key={j}>{p}</div>)}
          </li>
        ))}
      </ul>
    </div>
  )
}
```

This works. For a few hundred contacts, it's fine.

---

## Where the Naive Version Falls Down

With thousands of contacts, problems compound at every layer:

| Layer | Problem |
|-------|---------|
| **Native fetch** | `enumerateContacts` reads every contact from disk. 10,000 contacts = hundreds of milliseconds. |
| **Bridge serialization** | The entire array is serialized to JSON and copied across the JS/native boundary. Large payloads take 50-200ms+ just for the copy. |
| **React render** | Rendering 10,000 list items is slow. The browser has to layout and paint all of them, even the ones off-screen. |
| **Client-side filter** | Filtering 10,000 contacts on every keystroke causes noticeable lag, even with `useMemo`. |

The timing instrumentation in this project makes all of this visible. With 10,000 contacts, you'll see something like:

```
Native fetch: 350ms
Bridge serialization: 150ms
React render: 200ms
```

700ms of blank screen before the user sees anything.

---

## Step 2: Enhancements

### 1. Pagination with Early Stopping

The biggest win. Instead of fetching all contacts, fetch one page at a time and **stop the enumeration early**:

```swift
func search(query: String?, offset: Int, limit: Int) async throws
    -> (contacts: [[String: Any]], hasMore: Bool, fetchMs: Double)
{
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let store = CNContactStore()
                let fetchStart = CFAbsoluteTimeGetCurrent()
                let keys: [CNKeyDescriptor] = [
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor,
                    CNContactPhoneNumbersKey as CNKeyDescriptor,
                ]

                var skipped = 0
                var collected: [[String: Any]] = []
                var foundMore = false
                let request = CNContactFetchRequest(keysToFetch: keys)

                try store.enumerateContacts(with: request) { contact, stop in
                    // Skip contacts before our offset
                    if skipped < offset {
                        skipped += 1
                        return
                    }
                    // Once we have enough, stop enumeration entirely
                    if collected.count >= limit {
                        foundMore = true
                        stop.pointee = true  // <-- This is the key line
                        return
                    }
                    collected.append([
                        "givenName": contact.givenName,
                        "familyName": contact.familyName,
                        "phoneNumbers": contact.phoneNumbers.map { $0.value.stringValue },
                    ])
                }

                let fetchMs = (CFAbsoluteTimeGetCurrent() - fetchStart) * 1000
                continuation.resume(returning: (collected, foundMore, fetchMs))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

`stop.pointee = true` halts `enumerateContacts` immediately. Fetching page 1 of 10,000 contacts now only reads ~101 contacts instead of all 10,000.

The return value includes `hasMore` so the client knows whether to request another page.

### 2. Native Search via Predicates

When the user searches, use Apple's `CNContact.predicateForContacts(matchingName:)` instead of fetching everything and filtering in JS:

```swift
if let query = query, !query.isEmpty {
    let predicate = CNContact.predicateForContacts(matchingName: query)
    let results = try store.unifiedContacts(matching: predicate, keysToFetch: keys)

    // unifiedContacts has no pagination API, so slice in memory
    let allContacts = results.map { contact in
        [
            "givenName": contact.givenName,
            "familyName": contact.familyName,
            "phoneNumbers": contact.phoneNumbers.map { $0.value.stringValue },
        ] as [String: Any]
    }
    let end = min(offset + limit, allContacts.count)
    page = offset < allContacts.count ? Array(allContacts[offset..<end]) : []
    hasMore = (offset + limit) < allContacts.count
} else {
    // No query: use early-stopping enumeration (shown above)
}
```

Two strategies depending on context:
- **Browsing (no query):** `enumerateContacts` with early stopping — avoids reading the full contact store
- **Searching:** `unifiedContacts(matching:)` — Apple's predicate engine does the filtering natively, which is much faster than pulling all contacts across the bridge and filtering in JS. Note: this API has no built-in pagination, so we fetch all matches and slice in memory. For most search queries this is fine because the result set is small.

### 3. Infinite Scroll

Use an `IntersectionObserver` on a sentinel element at the bottom of the list. When it comes into view, fetch the next page:

```tsx
const PAGE_SIZE = 100
const sentinelRef = useRef<HTMLDivElement>(null)

useEffect(() => {
  const sentinel = sentinelRef.current
  if (!sentinel) return

  const observer = new IntersectionObserver(
    async (entries) => {
      const entry = entries[0]
      if (!entry.isIntersecting) return
      if (loadingMore || loading || !hasMore) return

      setLoadingMore(true)
      const { result } = await fetchPage(currentQueryRef.current, contacts.length)
      setContacts((prev) => [...prev, ...result.contacts])
      setHasMore(result.hasMore)
      setLoadingMore(false)
    },
    { rootMargin: '200px' }  // Start fetching 200px before the user reaches the bottom
  )

  observer.observe(sentinel)
  return () => observer.disconnect()
}, [contacts.length, hasMore, loading, loadingMore, fetchPage])

// In JSX:
<ul>{/* contact items */}</ul>
<div ref={sentinelRef} style={{ height: 1 }} />
{loadingMore && <div>Loading more...</div>}
```

The `rootMargin: '200px'` triggers the fetch before the user actually reaches the bottom, making pagination feel seamless.

### 4. Search Debouncing

Don't fire a native search on every keystroke. Wait until the user pauses:

```tsx
const DEBOUNCE_MS = 300
const debounceRef = useRef<ReturnType<typeof setTimeout>>(null)
const initialLoadRef = useRef(true)

useEffect(() => {
  if (debounceRef.current) clearTimeout(debounceRef.current)

  debounceRef.current = setTimeout(async () => {
    setLoading(true)
    setContacts([])  // Reset for new query

    const { result, bridgeMs } = await fetchPage(query, 0)
    setContacts(result.contacts)
    setHasMore(result.hasMore)
    setLoading(false)
  }, initialLoadRef.current ? 0 : DEBOUNCE_MS)  // No delay on first load
  initialLoadRef.current = false

  return () => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
  }
}, [query, fetchPage])
```

The initial load fires immediately (no 300ms wait for the first page), and subsequent searches debounce.

### 5. Off-Main-Thread Contact Access

`CNContactStore` methods like `enumerateContacts` and `execute` **must not run on the main thread** — they will block the UI and trigger Apple's "This method should not be called on the main thread" warning.

The pattern used throughout:

```swift
func fetchAll() async throws -> (...) {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            // All CNContactStore work happens here, off-main
            let store = CNContactStore()
            try store.enumerateContacts(with: request) { ... }
            continuation.resume(returning: ...)
        }
    }
}
```

Why `DispatchQueue.global` + `withCheckedThrowingContinuation` instead of just `Task.detached`? Swift concurrency doesn't guarantee which thread a detached task runs on — it could still end up on the main thread. The explicit `DispatchQueue.global` guarantees a background thread.

### 6. Performance Instrumentation

Every response includes timing breakdowns so you can see where time is spent:

**Swift side** — measure auth and fetch separately:
```swift
let totalStart = CFAbsoluteTimeGetCurrent()
let (granted, authMs) = await service.requestAccess()
let (contacts, fetchMs) = try await service.fetchAll()
let totalMs = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000
```

**JS side** — measure bridge overhead and React render time:
```typescript
const bridgeStart = performance.now()
const result = await window.webkit!.messageHandlers.getContacts.postMessage('fetch')
const bridgeMs = Math.round((performance.now() - bridgeStart) * 10) / 10

// Bridge overhead = total round-trip minus native work
const bridgeOverheadMs = Math.round((bridgeMs - result.timing.totalNativeMs) * 10) / 10

// Render time: measure from setState to paint
const stateStart = performance.now()
setContacts(result.contacts)
requestAnimationFrame(() => {
  const renderMs = Math.round((performance.now() - stateStart) * 10) / 10
})
```

This produces a breakdown like:

```
Native auth: 0.5ms
Native fetch: 12.3ms
Native total: 12.8ms
Bridge serialization: 3.2ms
Bridge round-trip: 16.0ms
React render: 4.1ms
```

Bridge serialization overhead is isolated by subtracting native time from the total round-trip. This tells you how much time is spent just copying data across the JS/native boundary — the cost that grows with payload size and is directly reduced by pagination.

---

## Running the Project

### Web (from `/web`)
```bash
npm install
npm run dev          # Dev server with HMR
npm run build        # Production build
```

### iOS
1. Build the web app and copy it into the Xcode project:
   ```bash
   cd web && npm run build && rm -rf ../native/WebApp && cp -r dist/client ../native/WebApp
   ```
2. Open `native/native-js-contacts-bridge-demo.xcodeproj` in Xcode
3. Build and run on a simulator or device
