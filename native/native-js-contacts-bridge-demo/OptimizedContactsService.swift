import Contacts
import os

private let logger = Logger(subsystem: "native-js-contacts-bridge-demo", category: "optimized-contacts")

class OptimizedContactsService {
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

    func search(query: String?, offset: Int, limit: Int) async throws -> (contacts: [[String: Any]], hasMore: Bool, fetchMs: Double) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let store = CNContactStore()
                    let fetchStart = CFAbsoluteTimeGetCurrent()
                    let keys: [CNKeyDescriptor] = [
                        CNContactGivenNameKey as CNKeyDescriptor,
                        CNContactFamilyNameKey as CNKeyDescriptor,
                        CNContactPhoneNumbersKey as CNKeyDescriptor
                    ]

                    let page: [[String: Any]]
                    let hasMore: Bool

                    if let query = query, !query.isEmpty {
                        // Search query: unifiedContacts has no pagination API, fetch all matches and slice
                        let predicate = CNContact.predicateForContacts(matchingName: query)
                        let results = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
                        let allContacts = results.map { contact in
                            [
                                "givenName": contact.givenName,
                                "familyName": contact.familyName,
                                "phoneNumbers": contact.phoneNumbers.map { $0.value.stringValue }
                            ] as [String: Any]
                        }
                        let end = min(offset + limit, allContacts.count)
                        page = offset < allContacts.count ? Array(allContacts[offset..<end]) : []
                        hasMore = (offset + limit) < allContacts.count
                    } else {
                        // No query: enumerate with early stopping — only visit offset + limit + 1 contacts
                        var skipped = 0
                        var collected: [[String: Any]] = []
                        var foundMore = false
                        let request = CNContactFetchRequest(keysToFetch: keys)
                        try store.enumerateContacts(with: request) { contact, stop in
                            if skipped < offset {
                                skipped += 1
                                return
                            }
                            if collected.count >= limit {
                                foundMore = true
                                stop.pointee = true
                                return
                            }
                            collected.append([
                                "givenName": contact.givenName,
                                "familyName": contact.familyName,
                                "phoneNumbers": contact.phoneNumbers.map { $0.value.stringValue }
                            ])
                        }
                        page = collected
                        hasMore = foundMore
                    }

                    let fetchMs = (CFAbsoluteTimeGetCurrent() - fetchStart) * 1000
                    logger.info("Search query=\(query ?? "<all>") offset=\(offset) returned=\(page.count) hasMore=\(hasMore) in \(fetchMs, format: .fixed(precision: 1))ms")
                    continuation.resume(returning: (page, hasMore, fetchMs))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
