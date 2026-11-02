import Foundation

struct CleanedLink: Equatable {
    var url: String
    var original: String
    var domain: String
    var removed: [String]
    var guessedTitle: String
}

enum LinkCleaner {
    /// Default tracking parameters stripped before a link is saved.
    static let defaultTrackers: [String] = [
        "utm_*", "fbclid", "gclid", "dclid", "gbraid", "wbraid", "msclkid", "yclid", "twclid", "ttclid",
        "li_fat_id", "mc_cid", "mc_eid", "igshid", "igsh", "si", "ref_src", "ref_url", "_hsenc", "_hsmi",
        "__hssc", "__hstc", "__hsfp", "hsCtaTracking", "mkt_tok", "oly_anon_id", "oly_enc_id", "vero_id",
        "vero_conv", "s_cid", "wickedid", "rb_clickid", "spm", "scm", "smid", "sr_share", "ncid", "cmpid",
        "trk", "trkCampaign", "ga_source", "ga_medium", "ga_campaign", "_ga", "_gl", "feature",
    ]

    static let shorteners: Set<String> = [
        "t.co", "bit.ly", "tinyurl.com", "goo.gl", "ow.ly", "buff.ly", "is.gd", "lnkd.in", "rebrand.ly",
        "cutt.ly", "shorturl.at", "tiny.cc", "rb.gy", "dlvr.it", "fb.me", "trib.al", "apple.co", "spoti.fi",
    ]

    /// Parses free text into a cleaned link, or nil if it isn't a web address.
    static func parse(_ raw: String, trackers: [String] = defaultTrackers, strip: Bool = true) -> CleanedLink? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.contains(" "), !s.contains("\n"), s.count < 4096 else { return nil }
        if s.range(of: "^https?://", options: [.regularExpression, .caseInsensitive]) == nil {
            // Bare domain like "example.com/path"
            guard s.range(of: "^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+(:[0-9]+)?(/|\\?|#|$)", options: .regularExpression) != nil else {
                return nil
            }
            s = "https://" + s
        }
        guard var comps = URLComponents(string: s), let host = comps.host?.lowercased(), host.contains(".") || host == "localhost" else {
            return nil
        }
        // TLD must be letters (rules out things like "1.5")
        if let tld = host.split(separator: ".").last, tld.range(of: "^[a-z]{2,}$", options: .regularExpression) == nil, host != "localhost" {
            return nil
        }
        comps.host = host
        var removed: [String] = []
        if strip, let items = comps.queryItems, !items.isEmpty {
            let kept = items.filter { item in
                if matches(item.name, trackers) { removed.append(item.name); return false }
                return true
            }
            comps.queryItems = kept.isEmpty ? nil : kept
        }
        guard let url = comps.url?.absoluteString else { return nil }
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return CleanedLink(url: url, original: raw.trimmingCharacters(in: .whitespacesAndNewlines),
                           domain: domain, removed: removed, guessedTitle: guessTitle(comps, domain: domain))
    }

    static func matches(_ name: String, _ patterns: [String]) -> Bool {
        let n = name.lowercased()
        for p in patterns {
            let pl = p.lowercased()
            if pl.hasSuffix("*") {
                if n.hasPrefix(String(pl.dropLast())) { return true }
            } else if n == pl {
                return true
            }
        }
        return false
    }

    static func guessTitle(_ comps: URLComponents, domain: String) -> String {
        let segs = comps.path.split(separator: "/").map(String.init)
        guard var seg = segs.last?.removingPercentEncoding else { return domain }
        if let dot = seg.range(of: "\\.[A-Za-z0-9]+$", options: .regularExpression) { seg.removeSubrange(dot) }
        seg = seg.replacingOccurrences(of: "[-_+]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if seg.isEmpty || seg.range(of: "^[0-9]+$", options: .regularExpression) != nil || seg.count < 3 {
            return domain
        }
        return seg.prefix(1).uppercased() + seg.dropFirst()
    }

    static func isShortLink(_ domain: String) -> Bool { shorteners.contains(domain) }
}
