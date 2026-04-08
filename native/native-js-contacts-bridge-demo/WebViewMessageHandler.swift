import WebKit

protocol MessageHandlerDelegate: AnyObject {
    func registeredHandlerNames() -> [String]
    func handleMessage(name: String, body: Any) async -> (Any?, String?)
}

class ContactsMessageDelegate: MessageHandlerDelegate {
    private let service = ContactsService()

    func registeredHandlerNames() -> [String] {
        ["getContacts"]
    }

    func handleMessage(name: String, body: Any) async -> (Any?, String?) {
        guard name == "getContacts" else { return (nil, "Unknown handler: \(name)") }

        let service = self.service
        return await Task.detached {
            let totalStart = CFAbsoluteTimeGetCurrent()

            let (granted, authMs) = await service.requestAccess()
            guard granted else { return (nil as Any?, "Contacts access denied") }

            do {
                let (contacts, fetchMs) = try await service.fetchAll()
                let totalMs = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000

                let timing: [String: Any] = [
                    "authMs": round(authMs * 10) / 10,
                    "fetchMs": round(fetchMs * 10) / 10,
                    "totalNativeMs": round(totalMs * 10) / 10
                ]
                let result: [String: Any] = [
                    "contacts": contacts,
                    "timing": timing
                ]
                return (result, nil)
            } catch {
                return (nil, error.localizedDescription)
            }
        }.value
    }
}

class OptimizedContactsMessageDelegate: MessageHandlerDelegate {
    private let service = OptimizedContactsService()

    func registeredHandlerNames() -> [String] {
        ["searchContacts"]
    }

    func handleMessage(name: String, body: Any) async -> (Any?, String?) {
        guard name == "searchContacts" else { return (nil, "Unknown handler: \(name)") }

        let params = body as? [String: Any] ?? [:]
        let query = params["query"] as? String
        let offset = params["offset"] as? Int ?? 0
        let limit = params["limit"] as? Int ?? 100

        let service = self.service
        return await Task.detached {
            let totalStart = CFAbsoluteTimeGetCurrent()

            let (granted, authMs) = await service.requestAccess()
            guard granted else { return (nil as Any?, "Contacts access denied") }

            do {
                let (contacts, hasMore, fetchMs) = try await service.search(query: query, offset: offset, limit: limit)
                let totalMs = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000

                let timing: [String: Any] = [
                    "authMs": round(authMs * 10) / 10,
                    "fetchMs": round(fetchMs * 10) / 10,
                    "totalNativeMs": round(totalMs * 10) / 10
                ]
                let result: [String: Any] = [
                    "contacts": contacts,
                    "hasMore": hasMore,
                    "timing": timing
                ]
                return (result, nil)
            } catch {
                return (nil, error.localizedDescription)
            }
        }.value
    }
}

class StressTestMessageDelegate: MessageHandlerDelegate {
    private let service = StressTestService()

    func registeredHandlerNames() -> [String] {
        ["generateContacts", "cleanupContacts"]
    }

    func handleMessage(name: String, body: Any) async -> (Any?, String?) {
        switch name {
        case "generateContacts":
            return await handleGenerate(body)
        case "cleanupContacts":
            return await handleCleanup(body)
        default:
            return (nil, "Unknown handler: \(name)")
        }
    }

    private func handleGenerate(_ body: Any) async -> (Any?, String?) {
        let params = body as? [String: Any] ?? [:]
        let count = params["count"] as? Int ?? 1000
        let prefix = params["prefix"] as? String ?? "ZZTest"

        let service = self.service
        return await Task.detached {
            let totalStart = CFAbsoluteTimeGetCurrent()

            let (granted, _) = await service.requestAccess()
            guard granted else { return (nil as Any?, "Contacts access denied") }

            do {
                let (created, generateMs) = try await service.generate(count: count, prefix: prefix)
                let totalMs = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000

                let timing: [String: Any] = [
                    "generateMs": round(generateMs * 10) / 10,
                    "totalMs": round(totalMs * 10) / 10
                ]
                let result: [String: Any] = [
                    "created": created,
                    "timing": timing
                ]
                return (result, nil)
            } catch {
                return (nil, error.localizedDescription)
            }
        }.value
    }

    private func handleCleanup(_ body: Any) async -> (Any?, String?) {
        let params = body as? [String: Any] ?? [:]
        let prefix = params["prefix"] as? String ?? "ZZTest"

        let service = self.service
        return await Task.detached {
            let totalStart = CFAbsoluteTimeGetCurrent()

            let (granted, _) = await service.requestAccess()
            guard granted else { return (nil as Any?, "Contacts access denied") }

            do {
                let (deleted, _) = try await service.cleanup(prefix: prefix)
                let totalMs = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000

                let timing: [String: Any] = [
                    "totalMs": round(totalMs * 10) / 10
                ]
                let result: [String: Any] = [
                    "deleted": deleted,
                    "timing": timing
                ]
                return (result, nil)
            } catch {
                return (nil, error.localizedDescription)
            }
        }.value
    }
}

class WebViewMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    private var delegates: [String: MessageHandlerDelegate] = [:]

    func addDelegate(_ delegate: MessageHandlerDelegate) {
        for name in delegate.registeredHandlerNames() {
            delegates[name] = delegate
        }
    }

    var allHandlerNames: [String] {
        Array(delegates.keys)
    }

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
