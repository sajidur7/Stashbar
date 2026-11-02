import AppKit
import Foundation
import Network

struct Session: Codable {
    var uid: String
    var refreshToken: String
    var idToken: String
    var expiresAt: Date
}

struct FirebaseUser {
    var uid: String
    var email: String
    var name: String
    var provider: AuthProvider
}

enum AuthError: LocalizedError {
    case notConfigured
    case cancelled
    case timedOut
    case stateMismatch
    case server(String)
    case needsRecentLogin
    case network

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Sign-in isn't set up yet. Add the Firebase API key to the app."
        case .cancelled: return "Sign-in was cancelled."
        case .timedOut: return "Sign-in timed out. Try again."
        case .stateMismatch: return "Sign-in response didn't match. Try again."
        case .server(let m): return Self.friendly(m)
        case .needsRecentLogin: return "For your safety, sign in again to confirm."
        case .network: return "Can't reach the internet. Check your connection and try again."
        }
    }

    static func friendly(_ code: String) -> String {
        switch code {
        case let c where c.contains("TOKEN_EXPIRED"), let c where c.contains("INVALID_REFRESH_TOKEN"),
             let c where c.contains("USER_NOT_FOUND"), let c where c.contains("USER_DISABLED"):
            return "Your session ended. Please sign in again."
        case let c where c.contains("OPERATION_NOT_ALLOWED"):
            return "This sign-in method isn't enabled yet."
        default:
            return code
        }
    }
}

/// Firebase Authentication over REST (no SDK). Sign-in itself happens in the browser on the
/// hosted page, which redirects to a one-shot loopback server with a refresh token.
final class AuthService {
    static let shared = AuthService()

    private(set) var session: Session?
    private let sessionURL: URL
    private var listener: LoopbackServer?

    init() {
        sessionURL = Storage.dir.appendingPathComponent("session.json")
        session = Storage.readSecure(Session.self, from: sessionURL)
    }

    var isSignedIn: Bool { session != nil }

    // MARK: Browser sign-in

    func signIn(provider: AuthProvider) async throws -> FirebaseUser {
        guard Config.isFirebaseConfigured else { throw AuthError.notConfigured }
        listener?.stop()
        let state = UUID().uuidString
        let server = LoopbackServer()
        listener = server
        let port = try await server.start()
        // The sign-in page is served by the app itself on http://localhost:<port>/auth.
        // "localhost" is on every Firebase project's authorised-domain list by default,
        // so this works without any extra console setup.
        var comps = URLComponents(string: "http://localhost:\(port)/auth")!
        comps.queryItems = [
            .init(name: "provider", value: provider == .google ? "google" : "apple"),
            .init(name: "state", value: state),
        ]
        await MainActor.run { _ = NSWorkspace.shared.open(comps.url!) }
        let params = try await server.waitForCallback(timeout: 300)
        listener = nil
        if params["error"] == "cancelled" { throw AuthError.cancelled }
        guard params["state"] == state else { throw AuthError.stateMismatch }
        guard let refresh = params["refresh_token"], !refresh.isEmpty else {
            throw AuthError.server(params["error"] ?? "No token returned")
        }
        try await exchange(refreshToken: refresh)
        var user = try await lookup()
        if let p = params["provider"], let ap = AuthProvider(rawValue: p) { user.provider = ap }
        return user
    }

    func cancelSignIn() {
        listener?.cancel()
        listener = nil
    }

    func signOut() {
        session = nil
        try? FileManager.default.removeItem(at: sessionURL)
    }

    // MARK: Tokens

    func validIDToken() async throws -> String {
        guard let s = session else { throw AuthError.server("Not signed in") }
        if s.expiresAt.timeIntervalSinceNow > 120 { return s.idToken }
        try await exchange(refreshToken: s.refreshToken)
        guard let fresh = session else { throw AuthError.server("Not signed in") }
        return fresh.idToken
    }

    private func exchange(refreshToken: String) async throws {
        var req = URLRequest(url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(Config.firebaseAPIKey)")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken.formEncoded)".data(using: .utf8)
        let json = try await Self.send(req)
        guard let id = json["id_token"] as? String, let rt = json["refresh_token"] as? String,
              let uid = json["user_id"] as? String else { throw AuthError.server("Bad token response") }
        let expires = Double(json["expires_in"] as? String ?? "3600") ?? 3600
        session = Session(uid: uid, refreshToken: rt, idToken: id, expiresAt: Date().addingTimeInterval(expires))
        Storage.writeSecure(session, to: sessionURL)
    }

    func lookup() async throws -> FirebaseUser {
        let token = try await validIDToken()
        var req = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=\(Config.firebaseAPIKey)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["idToken": token])
        let json = try await Self.send(req)
        guard let u = (json["users"] as? [[String: Any]])?.first else { throw AuthError.server("USER_NOT_FOUND") }
        let infos = u["providerUserInfo"] as? [[String: Any]] ?? []
        let providerID = infos.first?["providerId"] as? String ?? "google.com"
        let email = (u["email"] as? String) ?? (infos.first?["email"] as? String) ?? ""
        let name = (u["displayName"] as? String) ?? (infos.first?["displayName"] as? String) ?? ""
        return FirebaseUser(uid: u["localId"] as? String ?? session?.uid ?? "", email: email, name: name,
                            provider: AuthProvider(rawValue: providerID) ?? .google)
    }

    /// Deletes the Firebase Auth user. Throws `.needsRecentLogin` if Firebase wants a fresh sign-in.
    func deleteUser() async throws {
        let token = try await validIDToken()
        var req = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=\(Config.firebaseAPIKey)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["idToken": token])
        do {
            _ = try await Self.send(req)
        } catch AuthError.server(let m) where m.contains("CREDENTIAL_TOO_OLD") || m.contains("TOKEN_EXPIRED") {
            throw AuthError.needsRecentLogin
        }
        signOut()
    }

    static func send(_ req: URLRequest) async throws -> [String: Any] {
        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw AuthError.network
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = ((json["error"] as? [String: Any])?["message"] as? String)
                ?? (json["error"] as? String) ?? "HTTP \(http.statusCode)"
            throw AuthError.server(msg)
        }
        return json
    }
}

extension String {
    var formEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

// MARK: - Loopback HTTP server (127.0.0.1 only, one request)

final class LoopbackServer {
    private var listener: NWListener?
    private var continuation: CheckedContinuation<[String: String], Error>?
    private let queue = DispatchQueue(label: "stashbar.loopback")
    private var finished = false

    func start() async throws -> UInt16 {
        let params = NWParameters.tcp
        // Loopback only (both 127.0.0.1 and ::1, since browsers may resolve "localhost" to either).
        params.requiredInterfaceType = .loopback
        params.allowLocalEndpointReuse = true
        let l = try NWListener(using: params)
        listener = l
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UInt16, Error>) in
            var resumed = false
            l.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    cont.resume(returning: l.port?.rawValue ?? 0)
                case .failed(let e):
                    resumed = true
                    cont.resume(throwing: e)
                default: break
                }
            }
            l.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
            l.start(queue: queue)
        }
    }

    func waitForCallback(timeout: TimeInterval) async throws -> [String: String] {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                self.continuation = cont
                self.queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                    self?.finish(.failure(AuthError.timedOut))
                }
            }
        }
    }

    func cancel() { queue.async { self.finish(.failure(AuthError.cancelled)) } }
    func stop() { queue.async { self.finish(.failure(AuthError.cancelled)) } }

    private func finish(_ result: Result<[String: String], Error>) {
        guard !finished else { return }
        finished = true
        listener?.cancel()
        listener = nil
        continuation?.resume(with: result)
        continuation = nil
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self, let data, let text = String(data: data, encoding: .utf8),
                  let line = text.split(separator: "\r\n").first else { conn.cancel(); return }
            let parts = line.split(separator: " ")
            guard parts.count >= 2, parts[0] == "GET" else { conn.cancel(); return }
            let target = String(parts[1])
            if target.hasPrefix("/auth") {
                self.respond(conn, status: "200 OK", body: SignInPage.html)
                return
            }
            guard target.hasPrefix("/callback"), let comps = URLComponents(string: "http://localhost" + target) else {
                self.respond(conn, status: "404 Not Found", body: "Not found")
                return
            }
            var params: [String: String] = [:]
            for item in comps.queryItems ?? [] { params[item.name] = item.value ?? "" }
            let ok = params["refresh_token"] != nil
            self.respond(conn, status: "200 OK", body: Self.page(success: ok))
            self.finish(.success(params))
        }
    }

    private func respond(_ conn: NWConnection, status: String, body: String) {
        let bytes = Data(body.utf8)
        let head = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(bytes.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n"
        conn.send(content: Data(head.utf8) + bytes, completion: .contentProcessed { _ in conn.cancel() })
    }

    static func page(success: Bool) -> String {
        let title = success ? "You're signed in." : "Sign-in didn't finish."
        let body = success ? "Head back to Stashbar — your links are syncing. You can close this tab." : "Go back to Stashbar and try again."
        return """
        <!doctype html><html><head><meta charset="utf-8"><title>Stashbar</title>
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f4f2f0;font-family:-apple-system,system-ui,sans-serif;color:#0c0a08}
        .c{background:#fff;border:1px solid #ebe6df;border-radius:16px;padding:40px;max-width:420px;text-align:left}
        h1{font-weight:500;font-size:32px;letter-spacing:-.04em;margin:18px 0 10px}p{color:#6d6c6b;font-size:15px;line-height:1.55;margin:0}
        .i{width:56px;height:56px;border-radius:13px;background:#e4f222}</style></head>
        <body><div class="c"><div class="i"></div><h1>\(title)</h1><p>\(body)</p></div>
        <script>setTimeout(function(){window.close()},1500)</script></body></html>
        """
    }
}
