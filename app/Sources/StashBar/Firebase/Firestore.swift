import Foundation

/// Minimal Firestore REST client. Data layout:
///   users/{uid}                    profile (name, email, provider, photo bytes, monogramStyle)
///   users/{uid}/links/{linkId}     one document per link
///   users/{uid}/devices/{deviceId} Macs signed in to this account
/// Security rules (firebase/firestore.rules) only allow a user to touch their own tree.
final class Firestore {
    static let shared = Firestore()
    private let auth = AuthService.shared

    private var base: String {
        "https://firestore.googleapis.com/v1/projects/\(Config.firebaseProjectID)/databases/(default)/documents"
    }

    // MARK: Links

    func fetchLinks(uid: String) async throws -> [Link] {
        var out: [Link] = []
        var pageToken: String?
        repeat {
            var url = "\(base)/users/\(uid)/links?pageSize=300"
            if let t = pageToken { url += "&pageToken=\(t.formEncoded)" }
            let json = try await request("GET", url)
            for doc in json["documents"] as? [[String: Any]] ?? [] {
                if let l = Self.decodeLink(doc) { out.append(l) }
            }
            pageToken = json["nextPageToken"] as? String
        } while pageToken != nil
        return out
    }

    func upsert(_ link: Link, uid: String) async throws {
        _ = try await request("PATCH", "\(base)/users/\(uid)/links/\(link.id)", body: ["fields": Self.encode(link)])
    }

    func deleteLink(id: String, uid: String) async throws {
        _ = try await request("DELETE", "\(base)/users/\(uid)/links/\(id)")
    }

    // MARK: Profile

    func fetchProfile(uid: String) async throws -> [String: Any]? {
        do {
            let json = try await request("GET", "\(base)/users/\(uid)")
            return json["fields"] as? [String: Any]
        } catch FirestoreError.notFound {
            return nil
        }
    }

    func saveProfile(_ account: Account) async throws {
        var fields: [String: Any] = [
            "name": ["stringValue": account.name],
            "email": ["stringValue": account.email],
            "provider": ["stringValue": account.provider.rawValue],
            "monogramStyle": ["integerValue": String(account.monogramStyle)],
            "updatedAt": ["timestampValue": Self.iso.string(from: Date())],
        ]
        if let photo = account.photo {
            fields["photo"] = ["bytesValue": photo.base64EncodedString()]
        } else {
            fields["photo"] = ["nullValue": NSNull()]
        }
        _ = try await request("PATCH", "\(base)/users/\(account.uid)", body: ["fields": fields])
    }

    // MARK: Devices

    func touchDevice(_ device: Device, uid: String) async throws {
        let fields: [String: Any] = [
            "name": ["stringValue": device.name],
            "model": ["stringValue": device.model],
            "lastSeen": ["timestampValue": Self.iso.string(from: device.lastSeen)],
        ]
        _ = try await request("PATCH", "\(base)/users/\(uid)/devices/\(device.id)", body: ["fields": fields])
    }

    func fetchDevices(uid: String) async throws -> [Device] {
        let json = try await request("GET", "\(base)/users/\(uid)/devices?pageSize=50")
        return (json["documents"] as? [[String: Any]] ?? []).compactMap { doc in
            guard let name = doc["name"] as? String, let f = doc["fields"] as? [String: Any] else { return nil }
            return Device(id: String(name.split(separator: "/").last ?? ""),
                          name: Self.str(f["name"]) ?? "Mac",
                          model: Self.str(f["model"]) ?? "",
                          lastSeen: Self.date(f["lastSeen"]) ?? .distantPast)
        }
    }

    func deleteDevice(id: String, uid: String) async throws {
        _ = try await request("DELETE", "\(base)/users/\(uid)/devices/\(id)")
    }

    /// Removes every document the user owns. Used by "Delete account".
    func deleteEverything(uid: String) async throws {
        for l in try await fetchLinks(uid: uid) { try await deleteLink(id: l.id, uid: uid) }
        for d in (try? await fetchDevices(uid: uid)) ?? [] { try? await deleteDevice(id: d.id, uid: uid) }
        _ = try? await request("DELETE", "\(base)/users/\(uid)")
    }

    // MARK: Transport

    enum FirestoreError: LocalizedError {
        case notFound, permission, server(String), offline
        var errorDescription: String? {
            switch self {
            case .notFound: return "Not found"
            case .permission: return "Permission denied — check Firestore rules"
            case .server(let m): return m
            case .offline: return "Offline"
            }
        }
    }

    private func request(_ method: String, _ url: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        let token = try await auth.validIDToken()
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw FirestoreError.offline
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let http = resp as? HTTPURLResponse else { return json }
        switch http.statusCode {
        case 200..<300: return json
        case 404: throw FirestoreError.notFound
        case 401, 403: throw FirestoreError.permission
        default:
            let msg = (json["error"] as? [String: Any])?["message"] as? String ?? "HTTP \(http.statusCode)"
            throw FirestoreError.server(msg)
        }
    }

    // MARK: Encoding

    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let isoPlain = ISO8601DateFormatter()

    static func encode(_ l: Link) -> [String: Any] {
        func s(_ v: String) -> [String: Any] { ["stringValue": v] }
        func b(_ v: Bool) -> [String: Any] { ["booleanValue": v] }
        func t(_ v: Date) -> [String: Any] { ["timestampValue": iso.string(from: v)] }
        func a(_ v: [String]) -> [String: Any] { ["arrayValue": v.isEmpty ? [:] : ["values": v.map { s($0) }]] }
        var f: [String: Any] = [
            "url": s(l.url), "originalURL": s(l.originalURL), "title": s(l.title), "domain": s(l.domain),
            "tags": a(l.tags), "note": s(l.note), "pinned": b(l.pinned), "archived": b(l.archived),
            "opened": b(l.opened), "trackersRemoved": a(l.trackersRemoved),
            "createdAt": t(l.createdAt), "updatedAt": t(l.updatedAt),
        ]
        if let p = l.previewImageURL { f["previewImageURL"] = s(p) }
        return f
    }

    static func decodeLink(_ doc: [String: Any]) -> Link? {
        guard let name = doc["name"] as? String, let f = doc["fields"] as? [String: Any],
              let url = str(f["url"]) else { return nil }
        let id = String(name.split(separator: "/").last ?? "")
        return Link(id: id, url: url, originalURL: str(f["originalURL"]) ?? url, title: str(f["title"]) ?? url,
                    domain: str(f["domain"]) ?? "", tags: arr(f["tags"]), note: str(f["note"]) ?? "",
                    pinned: bool(f["pinned"]), archived: bool(f["archived"]), opened: bool(f["opened"]),
                    trackersRemoved: arr(f["trackersRemoved"]),
                    createdAt: date(f["createdAt"]) ?? Date(), updatedAt: date(f["updatedAt"]) ?? Date(),
                    previewImageURL: str(f["previewImageURL"]))
    }

    static func str(_ v: Any?) -> String? { (v as? [String: Any])?["stringValue"] as? String }
    static func bool(_ v: Any?) -> Bool { (v as? [String: Any])?["booleanValue"] as? Bool ?? false }
    static func int(_ v: Any?) -> Int? {
        if let s = (v as? [String: Any])?["integerValue"] as? String { return Int(s) }
        return (v as? [String: Any])?["integerValue"] as? Int
    }
    static func bytes(_ v: Any?) -> Data? {
        guard let s = (v as? [String: Any])?["bytesValue"] as? String else { return nil }
        return Data(base64Encoded: s)
    }
    static func arr(_ v: Any?) -> [String] {
        let values = ((v as? [String: Any])?["arrayValue"] as? [String: Any])?["values"] as? [[String: Any]] ?? []
        return values.compactMap { $0["stringValue"] as? String }
    }
    static func date(_ v: Any?) -> Date? {
        guard let s = (v as? [String: Any])?["timestampValue"] as? String else { return nil }
        return iso.date(from: s) ?? isoPlain.date(from: s)
    }
}
