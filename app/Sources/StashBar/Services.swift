import AppKit
import Carbon.HIToolbox
import Foundation
import UniformTypeIdentifiers

// MARK: - Page metadata (title, preview image, final URL after redirects)

struct PageMeta {
    var title: String?
    var imageURL: String?
    var finalURL: String?

    static func fetch(_ urlString: String) async -> PageMeta {
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else { return PageMeta() }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return PageMeta() }
        let final = resp.url?.absoluteString
        guard let mime = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type"), mime.contains("html") else {
            return PageMeta(finalURL: final)
        }
        let html = String(decoding: data.prefix(600_000), as: UTF8.self)
        return PageMeta(title: parseTitle(html), imageURL: meta(html, "og:image").flatMap { abs($0, base: resp.url) },
                        finalURL: final)
    }

    static func parseTitle(_ html: String) -> String? {
        if let og = meta(html, "og:title") ?? meta(html, "twitter:title") { return clean(og) }
        guard let r = html.range(of: "<title[^>]*>([\\s\\S]*?)</title>", options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let inner = html[r].replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return clean(inner)
    }

    static func meta(_ html: String, _ prop: String) -> String? {
        let patterns = [
            "<meta[^>]+(?:property|name)=[\"']\(prop)[\"'][^>]*content=[\"']([^\"']*)[\"']",
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]*(?:property|name)=[\"']\(prop)[\"']",
        ]
        for p in patterns {
            guard let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]),
                  let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let r = Range(m.range(at: 1), in: html) else { continue }
            let v = String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { return v }
        }
        return nil
    }

    static func abs(_ s: String, base: URL?) -> String? {
        if s.hasPrefix("http") { return s }
        guard let base, let u = URL(string: s, relativeTo: base) else { return nil }
        return u.absoluteString
    }

    static func clean(_ s: String) -> String? {
        var t = s
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&#x27;": "'",
                        "&apos;": "'", "&nbsp;": " ", "&mdash;": "—", "&ndash;": "–", "&hellip;": "…", "&rsquo;": "’", "&lsquo;": "‘",
                        "&ldquo;": "“", "&rdquo;": "”"]
        for (k, v) in entities { t = t.replacingOccurrences(of: k, with: v) }
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : String(t.prefix(300))
    }
}

/// Downloads and caches preview images.
enum PreviewCache {
    static func file(for url: String) -> URL {
        let name = String(url.utf8.reduce(UInt64(5381)) { ($0 << 5) &+ $0 &+ UInt64($1) }, radix: 16)
        return Storage.cacheDir.appendingPathComponent(name)
    }

    static func image(for url: String) async -> NSImage? {
        let f = file(for: url)
        if let img = NSImage(contentsOf: f) { return img }
        guard let u = URL(string: url), let (data, _) = try? await URLSession.shared.data(from: u),
              data.count < 5_000_000, let img = NSImage(data: data) else { return nil }
        try? data.write(to: f)
        return img
    }
}

// MARK: - Clipboard watcher (local only; text never leaves the Mac)

@MainActor
final class ClipboardWatcher {
    static let shared = ClipboardWatcher()
    private var lastChange = NSPasteboard.general.changeCount
    private var ignoreChange: Int?
    private var timer: Timer?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // Check what's already on the clipboard at launch.
        Store.shared.clipboardChanged(NSPasteboard.general.string(forType: .string))
    }

    private func tick() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChange else { return }
        lastChange = pb.changeCount
        if pb.changeCount == ignoreChange { return }
        // Respect password managers that mark items as concealed/transient.
        let types = pb.types ?? []
        if types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) ||
            types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")) { return }
        Store.shared.clipboardChanged(pb.string(forType: .string))
    }

    func writeIgnoringChange(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
        ignoreChange = pb.changeCount
        lastChange = pb.changeCount
    }
}

// MARK: - Global hotkeys (Carbon; no Accessibility permission required)

final class HotKeys {
    static let shared = HotKeys()
    static let options = ["⌥S", "⌃⌥S", "⇧⌘S"]

    var onOpen: (() -> Void)?
    var onQuickStash: (() -> Void)?
    private var refs: [EventHotKeyRef?] = []
    private var handlerInstalled = false

    func reload() {
        for r in refs { if let r { UnregisterEventHotKey(r) } }
        refs = []
        installHandler()
        let (mods, key) = Self.parse(Prefs.shared.openShortcut)
        register(id: 1, key: key, mods: mods)
        // Quick stash = open shortcut + Shift (⌥⇧S by default)
        register(id: 2, key: key, mods: mods | UInt32(shiftKey))
    }

    static func parse(_ s: String) -> (UInt32, UInt32) {
        var m: UInt32 = 0
        if s.contains("⌥") { m |= UInt32(optionKey) }
        if s.contains("⌃") { m |= UInt32(controlKey) }
        if s.contains("⌘") { m |= UInt32(cmdKey) }
        if s.contains("⇧") { m |= UInt32(shiftKey) }
        return (m, UInt32(kVK_ANSI_S))
    }

    private func register(id: UInt32, key: UInt32, mods: UInt32) {
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x53544252), id: id) // 'STBR'
        let status = RegisterEventHotKey(key, mods, hkID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr { refs.append(ref) }
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            DispatchQueue.main.async {
                if hk.id == 1 { HotKeys.shared.onOpen?() } else if hk.id == 2 { HotKeys.shared.onQuickStash?() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

// MARK: - Import / export

enum ImportExport {
    enum Format: String, CaseIterable { case json = "JSON", markdown = "Markdown", html = "Bookmarks HTML" }

    @MainActor
    static func export(_ links: [Link], format: Format? = nil) {
        let panel = NSSavePanel()
        let stamp: String = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }()
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: Format.allCases.map { $0.rawValue })
        if let format { popup.selectItem(withTitle: format.rawValue) }
        let label = NSTextField(labelWithString: "Format:")
        let stack = NSStackView(views: [label, popup])
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        panel.accessoryView = stack
        func ext(_ f: Format) -> String { f == .json ? "json" : (f == .markdown ? "md" : "html") }
        let initial = format ?? .json
        panel.nameFieldStringValue = "stashbar-\(stamp).\(ext(initial))"
        let helper = PopupTarget { title in
            let f = Format(rawValue: title) ?? .json
            let base = (panel.nameFieldStringValue as NSString).deletingPathExtension
            panel.nameFieldStringValue = base + "." + ext(f)
        }
        popup.target = helper
        popup.action = #selector(PopupTarget.changed(_:))
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        _ = helper
        let f = Format(rawValue: popup.titleOfSelectedItem ?? "JSON") ?? .json
        let content: String
        switch f {
        case .json: content = json(links)
        case .markdown: content = markdown(links)
        case .html: content = bookmarksHTML(links)
        }
        try? content.write(to: url, atomically: true, encoding: .utf8)
        Store.shared.celebrate("Exported \(links.count) links")
    }

    final class PopupTarget: NSObject {
        let onChange: (String) -> Void
        init(_ c: @escaping (String) -> Void) { onChange = c }
        @objc func changed(_ sender: NSPopUpButton) { onChange(sender.titleOfSelectedItem ?? "") }
    }

    static func json(_ links: [Link]) -> String {
        let items: [[String: Any]] = links.map {
            ["url": $0.url, "title": $0.title, "domain": $0.domain, "tags": $0.tags, "note": $0.note,
             "pinned": $0.pinned, "archived": $0.archived, "createdAt": Firestore.isoPlain.string(from: $0.createdAt)]
        }
        let data = (try? JSONSerialization.data(withJSONObject: ["app": "Stashbar", "links": items],
                                                options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    static func markdown(_ links: [Link]) -> String {
        var out = "# Stashbar links\n\n"
        for l in links {
            let tags = l.tags.isEmpty ? "" : " " + l.tags.map { "`#\($0)`" }.joined(separator: " ")
            out += "- [\(l.title.replacingOccurrences(of: "]", with: "\\]"))](\(l.url))\(tags)\n"
            if !l.note.isEmpty { out += "  > \(l.note.replacingOccurrences(of: "\n", with: " "))\n" }
        }
        return out
    }

    static func bookmarksHTML(_ links: [Link]) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
        }
        var out = "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n<TITLE>Bookmarks</TITLE>\n<H1>Bookmarks</H1>\n<DL><p>\n<DT><H3>Stashbar</H3>\n<DL><p>\n"
        for l in links {
            out += "<DT><A HREF=\"\(esc(l.url))\" ADD_DATE=\"\(Int(l.createdAt.timeIntervalSince1970))\" TAGS=\"\(esc(l.tags.joined(separator: ",")))\">\(esc(l.title))</A>\n"
        }
        out += "</DL><p>\n</DL><p>\n"
        return out
    }

    /// Bookmarks HTML (Safari / Chrome / Arc / Firefox export) or a Stashbar JSON export.
    @MainActor
    static func runImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html, .json, UTType(filenameExtension: "htm") ?? .html]
        panel.message = "Choose a bookmarks file exported from Safari, Chrome, Arc or Firefox — or a Stashbar .json export."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url, let text = try? String(contentsOf: url) else { return }
        let items = parse(text)
        let n = Store.shared.importLinks(items)
        Store.shared.celebrate(n == 0 ? "No new links found" : "Imported \(n) link\(n == 1 ? "" : "s")")
    }

    static func parse(_ text: String) -> [(url: String, title: String?)] {
        if let data = text.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = obj["links"] as? [[String: Any]] {
            return arr.compactMap { d in (d["url"] as? String).map { ($0, d["title"] as? String) } }
        }
        guard let re = try? NSRegularExpression(pattern: "<a[^>]+href=\"([^\"]+)\"[^>]*>([\\s\\S]*?)</a>",
                                                options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let href = ns.substring(with: m.range(at: 1))
            guard href.hasPrefix("http") else { return nil }
            let title = PageMeta.clean(ns.substring(with: m.range(at: 2)).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
            return (href.replacingOccurrences(of: "&amp;", with: "&"), title)
        }
    }
}

// MARK: - Updates (GitHub releases)

enum Updates {
    struct Result { var latest: String; var url: URL; var newer: Bool }

    static func check() async -> Result? {
        var req = URLRequest(url: Config.latestReleaseAPI)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let html = (json["html_url"] as? String).flatMap(URL.init(string:)) else { return nil }
        let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        return Result(latest: latest, url: html, newer: isNewer(latest, than: Config.appVersion))
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
