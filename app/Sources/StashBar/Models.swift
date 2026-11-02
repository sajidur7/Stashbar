import Foundation

struct Link: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var url: String            // cleaned URL
    var originalURL: String    // as copied
    var title: String
    var domain: String
    var tags: [String]
    var note: String
    var pinned: Bool
    var archived: Bool
    var opened: Bool
    var trackersRemoved: [String]
    var createdAt: Date
    var updatedAt: Date
    var previewImageURL: String?

    // Local-only sync bookkeeping (not uploaded).
    var dirty: Bool = false

    init(cleaned: CleanedLink, title: String? = nil, tags: [String] = []) {
        let now = Date()
        id = UUID().uuidString.lowercased()
        url = cleaned.url
        originalURL = cleaned.original
        self.title = title ?? cleaned.guessedTitle
        domain = cleaned.domain
        self.tags = tags
        note = ""
        pinned = false
        archived = false
        opened = false
        trackersRemoved = cleaned.removed
        createdAt = now
        updatedAt = now
        dirty = true
    }

    init(id: String, url: String, originalURL: String, title: String, domain: String, tags: [String], note: String,
         pinned: Bool, archived: Bool, opened: Bool, trackersRemoved: [String], createdAt: Date, updatedAt: Date,
         previewImageURL: String?) {
        self.id = id; self.url = url; self.originalURL = originalURL; self.title = title; self.domain = domain
        self.tags = tags; self.note = note; self.pinned = pinned; self.archived = archived; self.opened = opened
        self.trackersRemoved = trackersRemoved; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.previewImageURL = previewImageURL
    }
}

enum AuthProvider: String, Codable {
    case google = "google.com"
    case apple = "apple.com"

    var label: String { self == .google ? "Google" : "Apple" }
}

struct Account: Codable, Equatable {
    var uid: String
    var email: String
    var name: String
    var provider: AuthProvider
    var photo: Data?
    var monogramStyle: Int = 0

    var firstName: String {
        let n = name.split(separator: " ").first.map(String.init) ?? ""
        return n.isEmpty ? (email.split(separator: "@").first.map(String.init) ?? "there") : n
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first.map(String.init) }.joined()
        if !s.isEmpty { return s.uppercased() }
        return String(email.prefix(2)).uppercased()
    }
}

struct Device: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var model: String
    var lastSeen: Date
}

enum SyncStatus: Equatable {
    case idle(Date?)
    case syncing
    case offline
    case error(String)
}

enum CanvasView: Hashable {
    case all, pinned, unopened, archive
    case tag(String)

    var title: String {
        switch self {
        case .all: return "All links"
        case .pinned: return "Pinned"
        case .unopened: return "Unopened"
        case .archive: return "Archive"
        case .tag(let t): return "#" + t
        }
    }
}

enum RelativeTime {
    static func short(_ date: Date, now: Date = Date()) -> String {
        let mins = Int(now.timeIntervalSince(date) / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins)m" }
        let hours = Int((Double(mins) / 60).rounded())
        if hours < 24 { return "\(hours)h" }
        if hours < 48 { return "Yday" }
        let days = hours / 24
        if days < 7 {
            let f = DateFormatter(); f.dateFormat = "EEE"
            return f.string(from: date)
        }
        let f = DateFormatter(); f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    static func long(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "never" }
        let secs = now.timeIntervalSince(date)
        if secs < 60 { return "just now" }
        let mins = Int(secs / 60)
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return days == 1 ? "yesterday" : "\(days) days ago"
    }
}
