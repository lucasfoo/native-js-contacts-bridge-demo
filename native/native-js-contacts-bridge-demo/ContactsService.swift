import Contacts
import os

private let logger = Logger(subsystem: "native-js-contacts-bridge-demo", category: "contacts")

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
                        CNContactPhoneNumbersKey as CNKeyDescriptor
                    ]
                    let request = CNContactFetchRequest(keysToFetch: keys)
                    var contacts: [[String: Any]] = []

                    try store.enumerateContacts(with: request) { contact, _ in
                        contacts.append([
                            "givenName": contact.givenName,
                            "familyName": contact.familyName,
                            "phoneNumbers": contact.phoneNumbers.map { $0.value.stringValue }
                        ])
                    }

                    let fetchMs = (CFAbsoluteTimeGetCurrent() - fetchStart) * 1000
                    logger.info("Fetched \(contacts.count) contacts in \(fetchMs, format: .fixed(precision: 1))ms")
                    continuation.resume(returning: (contacts, fetchMs))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
