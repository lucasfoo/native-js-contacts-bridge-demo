import Contacts
import os

private let logger = Logger(subsystem: "native-js-contacts-bridge-demo", category: "optimized-contacts")

class OptimizedContactsService {
    private let store = CNContactStore()

    func requestAccess() async -> (granted: Bool, authMs: Double) {
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

    func search(query: String?, offset: Int, limit: Int) async throws -> (contacts: [[String: Any]], total: Int, fetchMs: Double) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let fetchStart = CFAbsoluteTimeGetCurrent()
                    let keys: [CNKeyDescriptor] = [
                        CNContactGivenNameKey as CNKeyDescriptor,
                        CNContactFamilyNameKey as CNKeyDescriptor,
                        CNContactPhoneNumbersKey as CNKeyDescriptor
                    ]

                    var allContacts: [[String: Any]] = []

                    if let query = query, !query.isEmpty {
                        let predicate = CNContact.predicateForContacts(matchingName: query)
                        let results = try self.store.unifiedContacts(matching: predicate, keysToFetch: keys)
                        allContacts = results.map { contact in
                            [
                                "givenName": contact.givenName,
                                "familyName": contact.familyName,
                                "phoneNumbers": contact.phoneNumbers.map { $0.value.stringValue }
                            ]
                        }
                    } else {
                        let request = CNContactFetchRequest(keysToFetch: keys)
                        try self.store.enumerateContacts(with: request) { contact, _ in
                            allContacts.append([
                                "givenName": contact.givenName,
                                "familyName": contact.familyName,
                                "phoneNumbers": contact.phoneNumbers.map { $0.value.stringValue }
                            ])
                        }
                    }

                    let total = allContacts.count
                    let end = min(offset + limit, total)
                    let page = offset < total ? Array(allContacts[offset..<end]) : []

                    let fetchMs = (CFAbsoluteTimeGetCurrent() - fetchStart) * 1000
                    logger.info("Search query=\(query ?? "<all>") total=\(total) offset=\(offset) returned=\(page.count) in \(fetchMs, format: .fixed(precision: 1))ms")
                    continuation.resume(returning: (page, total, fetchMs))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
