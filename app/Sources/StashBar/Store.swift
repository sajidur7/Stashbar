import AppKit
import SwiftUI

/// Single source of truth for links, account and sync state.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var links: [Link] = []
    @Published private(set) var account: Account?
    @Published private(set) var syncStatus: SyncStatus = .idle(nil)
    @Published private(set) var devices: [Device] = []
    @Published var clipboardLink: CleanedLink?
    @Published var clipboardNotALink = false
    @Published var toast: String?
    @Published var signingIn = false
    @Published var authError: String?
    @Published var lastSync: Date?

    let prefs = Prefs.shared
    private let auth = AuthService.shared
    private let fs = Firestore.shared
    private var tombstones: Set<String> = []
    private var dismissedClipURL: String?
    private var syncTask: Task<Void, Never>?
    private var syncDebounce: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    private let linksURL = Storage.dir.appendingPathComponent("links.json")
    private let accountURL = Storage.dir.appendingPathComponent("account.json")
    private let tombURL = Storage.dir.appendingPathComponent("tombstones.json")

    private init() {
        links = Storage.read([Link].self, from: linksURL) ?? []
        account = Storage.read(Account.self, from: accountURL)
        tombstones = Storage.read(Set<String>.self, from: tombURL) ?? []
        if account != nil && !auth.isSignedIn { account = nil } // session lost
        sortLinks()
    }

    // MARK: Derived

    var isSignedIn: Bool { account != nil }
    var isGuest: Bool { account == nil }
    var active: [Link] { links.filter { !$0.archived } }
    var pinned: [Link] { active.filter { $0.pinned } }
    var unopened: [Link] { active.filter { !$0.opened } }
    var archived: [Link] { links.filter { $0.archived } }

    var tags: [(String, Int)] {
        var counts: [String: Int] = [:]
        for l in active { for t in l.tags { counts[t, default: 0] += 1 } }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
    }

    func links(for view: CanvasView, query: String) -> [Link] {
        let base: [Link]
        switch view {
        case .all: base = active
        case .pinned: base = pinned
        case .unopened: base = unopened
        case .archive: base = archived
        case .tag(let t): base = active.filter { $0.tags.contains(t) }
        }
        return Self.filter(base, query: query)
    }

    /// Popover list: pinned first, then newest.
    func recent(query: String) -> [Link] {
        let list = Self.filter(active, query: query)
        let p = list.filter { $0.pinned }
        let rest = list.filter { !$0.pinned }
        return Array((p + rest).prefix(query.isEmpty ? prefs.popoverLimit : 50))
    }

    static func filter(_ list: [Link], query: String) -> [Link] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return list }
        let terms = q.split(separator: " ").map(String.init)
        return list.filter { l in
            let hay = (l.title + " " + l.domain + " " + l.url + " " + l.note + " " + l.tags.map { "#" + $0 }.joined(separator: " ")).lowercased()
            return terms.allSatisfy { hay.contains($0) }
        }
    }

    func link(_ id: String) -> Link? { links.first { $0.id == id } }

    // MARK: Mutations

    @discardableResult
    func stash(_ cleaned: CleanedLink, title: String? = nil, tags: [String] = []) -> Link {
        if let i = links.firstIndex(where: { $0.url == cleaned.url }) {
            // Already stashed: bring it back to the top.
            links[i].archived = false
            links[i].createdAt = Date()
            links[i].updatedAt = Date()
            for t in tags where !links[i].tags.contains(t) { links[i].tags.append(t) }
            if let title, !title.isEmpty { links[i].title = title }
            links[i].dirty = true
            let l = links[i]
            afterChange()
            celebrate("Already stashed — moved to top")
            return l
        }
        let link = Link(cleaned: cleaned, title: title, tags: tags)
        links.insert(link, at: 0)
        if clipboardLink?.url == cleaned.url || clipboardLink?.original == cleaned.original {
            clipboardLink = nil
        }
        afterChange()
        celebrate(cleaned.removed.isEmpty ? "Stashed" : "Stashed · \(cleaned.removed.count) tracker\(cleaned.removed.count == 1 ? "" : "s") removed")
        enrich(link.id, fetchTitle: title == nil)
        return link
    }

    func stashClipboard() -> Bool {
        if let c = clipboardLink {
            stash(c)
            return true
        }
        if let s = NSPasteboard.general.string(forType: .string),
           let c = LinkCleaner.parse(s, trackers: prefs.trackerList, strip: prefs.stripTrackers) {
            stash(c)
            return true
        }
        clipboardNotALink = true
        return false
    }

    func dismissClipboard() {
        dismissedClipURL = clipboardLink?.original
        clipboardLink = nil
    }

    func update(_ id: String, _ change: (inout Link) -> Void) {
        guard let i = links.firstIndex(where: { $0.id == id }) else { return }
        change(&links[i])
        links[i].updatedAt = Date()
        links[i].dirty = true
        afterChange()
    }

    func togglePin(_ id: String) { update(id) { $0.pinned.toggle() } }
    func archive(_ id: String) { update(id) { $0.archived = true; $0.pinned = false }; celebrate("Archived") }
    func restore(_ id: String) { update(id) { $0.archived = false }; celebrate("Restored to All links") }

    func delete(_ id: String) {
        links.removeAll { $0.id == id }
        if isSignedIn { tombstones.insert(id) }
        afterChange()
    }

    func open(_ link: Link) {
        if let url = URL(string: link.url) { NSWorkspace.shared.open(url) }
        if !link.opened { update(link.id) { $0.opened = true } }
    }

    func copy(_ link: Link) {
        let s = prefs.copyClean ? link.url : link.originalURL
        ClipboardWatcher.shared.writeIgnoringChange(s)
        celebrate("Link copied")
    }

    func addTag(_ id: String, _ tag: String) {
        let t = Self.normalizeTag(tag)
        guard !t.isEmpty else { return }
        update(id) { if !$0.tags.contains(t) { $0.tags.append(t) } }
    }

    func removeTag(_ id: String, _ tag: String) { update(id) { $0.tags.removeAll { $0 == tag } } }

    static func normalizeTag(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .lowercased().replacingOccurrences(of: " ", with: "-")
    }

    func importLinks(_ items: [(url: String, title: String?)]) -> Int {
        var added = 0
        let existing = Set(links.map { $0.url })
        for item in items {
            guard let c = LinkCleaner.parse(item.url, trackers: prefs.trackerList, strip: prefs.stripTrackers),
                  !existing.contains(c.url) else { continue }
            var l = Link(cleaned: c, title: item.title?.isEmpty == false ? item.title : nil)
            l.opened = true
            links.append(l)
            added += 1
        }
        sortLinks()
        afterChange()
        return added
    }

    private func afterChange() {
        sortLinks()
        persist()
        scheduleSync()
    }

    private func sortLinks() {
        links.sort { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        Storage.write(links, to: linksURL)
        Storage.write(tombstones, to: tombURL)
        if let account { Storage.write(account, to: accountURL) } else { try? FileManager.default.removeItem(at: accountURL) }
    }

    func celebrate(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
        if text.hasPrefix("Stashed"), prefs.playSound { NSSound(named: "Pop")?.play() }
    }

    // MARK: Enrichment (expand short links, fetch title & preview)

    private func enrich(_ id: String, fetchTitle: Bool) {
        guard let link = link(id) else { return }
        let expand = prefs.expandShortLinks && LinkCleaner.isShortLink(link.domain)
        Task {
            let meta = await PageMeta.fetch(link.url)
            guard let current = self.link(id) else { return }
            var newURL: CleanedLink?
            if expand, let final = meta.finalURL, final != link.url {
                newURL = LinkCleaner.parse(final, trackers: prefs.trackerList, strip: prefs.stripTrackers)
            }
            update(id) { l in
                if let n = newURL {
                    l.url = n.url
                    l.domain = n.domain
                    l.trackersRemoved += n.removed
                    if l.title == current.domain || l.title == "t.co" { l.title = n.guessedTitle }
                }
                if fetchTitle, let t = meta.title, !t.isEmpty, l.title == current.title { l.title = t }
                if let img = meta.imageURL { l.previewImageURL = img }
            }
        }
    }

    // MARK: Clipboard

    func clipboardChanged(_ text: String?) {
        clipboardNotALink = false
        guard prefs.watchClipboard, let text,
              let c = LinkCleaner.parse(text, trackers: prefs.trackerList, strip: prefs.stripTrackers) else {
            return
        }
        if c.original == dismissedClipURL { return }
        if active.contains(where: { $0.url == c.url }) { clipboardLink = nil; return }
        clipboardLink = c
    }

    // MARK: Account

    func signIn(_ provider: AuthProvider) async -> Bool {
        authError = nil
        signingIn = true
        defer { signingIn = false }
        do {
            let user = try await auth.signIn(provider: provider)
            var acct = Account(uid: user.uid, email: user.email, name: user.name, provider: user.provider)
            if let profile = try? await fs.fetchProfile(uid: user.uid) {
                if let n = Firestore.str(profile["name"]), !n.isEmpty, user.name.isEmpty { acct.name = n }
                acct.photo = Firestore.bytes(profile["photo"])
                acct.monogramStyle = Firestore.int(profile["monogramStyle"]) ?? 0
            }
            account = acct
            prefs.guestChosen = false
            // Guest links move into the account: mark them all for upload.
            for i in links.indices { links[i].dirty = true }
            persist()
            try? await fs.saveProfile(acct)
            await syncNow()
            return true
        } catch AuthError.cancelled {
            return false
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    func cancelSignIn() {
        auth.cancelSignIn()
        signingIn = false
    }

    /// keepLocal: leave a guest copy of links on this Mac.
    func signOut(keepLocal: Bool) {
        if let uid = account?.uid {
            let dev = Prefs.shared.deviceID
            Task { try? await fs.deleteDevice(id: dev, uid: uid) }
        }
        auth.signOut()
        account = nil
        devices = []
        tombstones = []
        lastSync = nil
        syncStatus = .idle(nil)
        if keepLocal {
            for i in links.indices { links[i].dirty = false }
        } else {
            links = []
        }
        prefs.guestChosen = true
        persist()
    }

    /// Deletes all server data and the Firebase user, then local data.
    func deleteAccount() async throws {
        guard let uid = account?.uid else { return }
        try await fs.deleteEverything(uid: uid)
        try await auth.deleteUser()
        account = nil
        links = []
        tombstones = []
        devices = []
        prefs.guestChosen = false
        persist()
    }

    func updateProfile(photo: Data?, monogramStyle: Int) {
        guard var a = account else { return }
        a.photo = photo
        a.monogramStyle = monogramStyle
        account = a
        persist()
        Task { try? await fs.saveProfile(a) }
    }

    // MARK: Sync

    func scheduleSync() {
        guard isSignedIn, prefs.autoSync else { return }
        syncDebounce?.cancel()
        syncDebounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func syncNow() async {
        guard let uid = account?.uid else { return }
        if let t = syncTask { await t.value; return }
        let task = Task { await performSync(uid: uid) }
        syncTask = task
        await task.value
        syncTask = nil
    }

    private func performSync(uid: String) async {
        syncStatus = .syncing
        do {
            for id in tombstones {
                do { try await fs.deleteLink(id: id, uid: uid) } catch Firestore.FirestoreError.notFound {}
                tombstones.remove(id)
            }
            for l in links where l.dirty {
                try await fs.upsert(l, uid: uid)
                if let i = links.firstIndex(where: { $0.id == l.id }), links[i].updatedAt == l.updatedAt {
                    links[i].dirty = false
                }
            }
            let remote = try await fs.fetchLinks(uid: uid)
            merge(remote)
            let host = Host.current().localizedName ?? "This Mac"
            try? await fs.touchDevice(Device(id: prefs.deviceID, name: host, model: Self.macModel(), lastSeen: Date()), uid: uid)
            devices = ((try? await fs.fetchDevices(uid: uid)) ?? []).sorted { $0.lastSeen > $1.lastSeen }
            lastSync = Date()
            syncStatus = .idle(lastSync)
            persist()
        } catch Firestore.FirestoreError.offline {
            syncStatus = .offline
        } catch AuthError.network {
            syncStatus = .offline
        } catch AuthError.server(let m) where m.contains("TOKEN") || m.contains("USER_NOT_FOUND") || m.contains("USER_DISABLED") {
            // Session revoked (e.g. account deleted on another Mac): fall back to guest, keep links.
            signOut(keepLocal: true)
            authError = AuthError.server(m).localizedDescription
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    private func merge(_ remote: [Link]) {
        let local = Dictionary(uniqueKeysWithValues: links.map { ($0.id, $0) })
        var result: [Link] = []
        var seen = Set<String>()
        for r in remote {
            seen.insert(r.id)
            if let l = local[r.id], l.dirty || l.updatedAt > r.updatedAt {
                var keep = l
                keep.dirty = true
                result.append(keep)
            } else {
                result.append(r)
            }
        }
        // Local links never uploaded stay; clean ones missing remotely were deleted elsewhere.
        for l in links where !seen.contains(l.id) && l.dirty { result.append(l) }
        links = result
        sortLinks()
    }

    static func macModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &buf, &size, nil, 0)
        return String(cString: buf)
    }

    var syncLabel: String {
        switch syncStatus {
        case .syncing: return "Syncing…"
        case .offline: return "Offline"
        case .error: return "Sync paused"
        case .idle(let d): return d == nil ? "Not synced yet" : "Synced " + RelativeTime.long(d)
        }
    }
}
