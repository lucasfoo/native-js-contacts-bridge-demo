import Contacts
import os

private let logger = Logger(subsystem: "native-js-contacts-bridge-demo", category: "stress-test")

private let givenNames = [
    // Chinese romanised given names
    "Ah Gao", "Wei Ling", "Jia Hui", "Zhi Wei", "Xiu Ying",
    "Jun Jie", "Mei Ling", "Siew Lan", "Kok Leong", "Hui Min",
    "Jia Ying", "Chun Kiat", "Pei Shan", "Yong Huat", "Shu Fen",
    "Kai Wen", "Xin Yi", "Boon Hock", "Li Hua", "Wai Keong",
    // Malay given names
    "Muhammad", "Nurul", "Ahmad", "Siti", "Mohd",
    "Farah", "Hafiz", "Aisyah", "Ismail", "Nur",
    "Amirul", "Syafiqah", "Irfan", "Hakim", "Zulaikha",
    // Indian given names
    "Priya", "Rajesh", "Kavitha", "Suresh", "Lakshmi",
    "Arun", "Deepa", "Ganesh", "Meera", "Vikram",
    "Anitha", "Ravi", "Shalini", "Dinesh", "Nirmala",
    // Western-style names common among Singaporeans
    "Peter", "Grace", "David", "Michelle", "Vincent",
    "Rachel", "Eugene", "Sharon", "Justin", "Cheryl",
    // Improperly formatted names (intentional for stress testing)
    "BOON KENG", "mei ling", "Ah  Kow", "J.", "S",
    " Wei Lin", "kumar ", "SITI NURHALIZA", "ah huat", "  David  "
]

private let familyNames = [
    // Chinese surnames (most common in Singapore)
    "Tan", "Lim", "Lee", "Ong", "Wong", "Goh", "Chua", "Chan",
    "Koh", "Teo", "Ang", "Yeo", "Ho", "Sim", "Ng", "Low",
    "Tay", "Foo", "Chong", "Leong", "Seah", "Phua", "Wee", "Heng",
    // Malay patronymics
    "bin Abdullah", "binte Mohd", "bin Ismail", "binte Hassan",
    "bin Osman", "binte Ahmad", "bin Yusof", "binte Ibrahim",
    // Indian surnames
    "Srinivasan", "Nair", "Pillai", "Muthu", "Kumar",
    "Subramanian", "Krishnan", "Naidu", "Sharma", "Rajan",
    "s/o Ramasamy", "d/o Krishnan", "s/o Muthu", "d/o Naidu",
    // Improperly formatted
    "TAN", "lee", "  Ng", "GOH ", "O'Brien"
]

private func generatePhoneNumber() -> String {
    let roll = Int.random(in: 0..<100)
    let sgPrefix = [8, 9].randomElement()!

    switch roll {
    // ~60% Singaporean mobile (+65, starts with 8 or 9)
    case 0..<12:
        // +65 9XXX XXXX (with spaces)
        return "+65 \(sgPrefix)\(Int.random(in: 100...999)) \(Int.random(in: 1000...9999))"
    case 12..<24:
        // +65-9XXXXXXX (dash separator, no spaces in number)
        return "+65-\(sgPrefix)\(Int.random(in: 1000000...9999999))"
    case 24..<36:
        // 9XXX XXXX (no country code, common local format)
        return "\(sgPrefix)\(Int.random(in: 100...999)) \(Int.random(in: 1000...9999))"
    case 36..<44:
        // 659XXXXXXX (country code mashed in, no +)
        return "65\(sgPrefix)\(Int.random(in: 1000000...9999999))"
    case 44..<52:
        // +6591234567 (no spaces or dashes)
        return "+65\(sgPrefix)\(Int.random(in: 1000000...9999999))"
    case 52..<60:
        // 9XXXXXXX (bare 8-digit number, no spaces)
        return "\(sgPrefix)\(Int.random(in: 1000000...9999999))"

    // ~15% Malaysian mobile (+60)
    case 60..<68:
        // +60 12-XXX XXXX
        let myPrefix = [12, 13, 14, 16, 17, 18, 19].randomElement()!
        return "+60 \(myPrefix)-\(Int.random(in: 100...999)) \(Int.random(in: 1000...9999))"
    case 68..<75:
        // +6012XXXXXXX (no formatting)
        let myPrefix = [12, 13, 16, 17].randomElement()!
        return "+60\(myPrefix)\(Int.random(in: 1000000...9999999))"

    // ~10% UK (+44)
    case 75..<80:
        // +44 7XXX XXXXXX
        return "+44 7\(Int.random(in: 100...999)) \(Int.random(in: 100000...999999))"
    case 80..<85:
        // +447XXXXXXXXX (no spaces)
        return "+447\(Int.random(in: 100000000...999999999))"

    // ~10% US (+1)
    case 85..<90:
        // +1 (XXX) XXX-XXXX
        return "+1 (\(Int.random(in: 200...999))) \(Int.random(in: 200...999))-\(Int.random(in: 1000...9999))"
    case 90..<95:
        // +1-XXX-XXX-XXXX
        return "+1-\(Int.random(in: 200...999))-\(Int.random(in: 200...999))-\(Int.random(in: 1000...9999))"

    // ~5% Edge cases
    case 95..<98:
        // Just digits, no formatting at all
        return "\(sgPrefix)\(Int.random(in: 1000000...9999999))"
    default:
        // Extra spaces in country code
        return "+65  \(Int.random(in: 80000000...99999999))"
    }
}

class StressTestService {
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

    func generate(count: Int, prefix: String) async throws -> (created: Int, generateMs: Double) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let store = CNContactStore()
                    let genStart = CFAbsoluteTimeGetCurrent()
                    let batchSize = 100
                    var created = 0

                    for batchStart in stride(from: 0, to: count, by: batchSize) {
                        let saveRequest = CNSaveRequest()
                        let batchEnd = min(batchStart + batchSize, count)
                        for _ in batchStart..<batchEnd {
                            let contact = CNMutableContact()
                            contact.givenName = "\(prefix) \(givenNames.randomElement()!)"
                            contact.familyName = familyNames.randomElement()!

                            let phoneCount = [1, 1, 1, 1, 1, 1, 2, 2, 2, 3].randomElement()!
                            var phones: [CNLabeledValue<CNPhoneNumber>] = []
                            for _ in 0..<phoneCount {
                                let number = generatePhoneNumber()
                                phones.append(CNLabeledValue(
                                    label: CNLabelPhoneNumberMobile,
                                    value: CNPhoneNumber(stringValue: number)
                                ))
                            }
                            contact.phoneNumbers = phones
                            saveRequest.add(contact, toContainerWithIdentifier: nil)
                        }
                        try store.execute(saveRequest)
                        created = batchEnd
                    }

                    let generateMs = (CFAbsoluteTimeGetCurrent() - genStart) * 1000
                    logger.info("Generated \(created) contacts in \(generateMs, format: .fixed(precision: 1))ms")
                    continuation.resume(returning: (created, generateMs))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func cleanup(prefix: String) async throws -> (deleted: Int, cleanupMs: Double) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let store = CNContactStore()
                    let cleanupStart = CFAbsoluteTimeGetCurrent()
                    let keys: [CNKeyDescriptor] = [
                        CNContactIdentifierKey as CNKeyDescriptor,
                        CNContactGivenNameKey as CNKeyDescriptor
                    ]
                    let request = CNContactFetchRequest(keysToFetch: keys)
                    var toDelete: [CNContact] = []

                    try store.enumerateContacts(with: request) { contact, _ in
                        if contact.givenName.hasPrefix(prefix) {
                            toDelete.append(contact)
                        }
                    }

                    let batchSize = 100
                    var deleted = 0
                    for batchStart in stride(from: 0, to: toDelete.count, by: batchSize) {
                        let saveRequest = CNSaveRequest()
                        let batchEnd = min(batchStart + batchSize, toDelete.count)
                        for i in batchStart..<batchEnd {
                            saveRequest.delete(toDelete[i].mutableCopy() as! CNMutableContact)
                        }
                        try store.execute(saveRequest)
                        deleted = batchEnd
                    }

                    let cleanupMs = (CFAbsoluteTimeGetCurrent() - cleanupStart) * 1000
                    logger.info("Cleaned up \(deleted) contacts in \(cleanupMs, format: .fixed(precision: 1))ms")
                    continuation.resume(returning: (deleted, cleanupMs))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
