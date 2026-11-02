import XCTest
@testable import StashBar

final class LinkCleanerTests: XCTestCase {
    func testStripsTrackers() throws {
        let c = try XCTUnwrap(LinkCleaner.parse("https://www.nytimes.com/2026/10/30/technology/menu-bar-apps-are-back.html?utm_source=x&utm_medium=social&smid=tw-share&id=7"))
        XCTAssertEqual(c.url, "https://www.nytimes.com/2026/10/30/technology/menu-bar-apps-are-back.html?id=7")
        XCTAssertEqual(c.domain, "nytimes.com")
        XCTAssertEqual(Set(c.removed), ["utm_source", "utm_medium", "smid"])
        XCTAssertEqual(c.guessedTitle, "Menu bar apps are back")
    }

    func testBareDomain() throws {
        let c = try XCTUnwrap(LinkCleaner.parse("arc.net/blog/tabs?utm_source=newsletter"))
        XCTAssertEqual(c.url, "https://arc.net/blog/tabs")
        XCTAssertEqual(c.removed, ["utm_source"])
    }

    func testRejectsNonLinks() {
        XCTAssertNil(LinkCleaner.parse("hello world"))
        XCTAssertNil(LinkCleaner.parse("1.5"))
        XCTAssertNil(LinkCleaner.parse(""))
        XCTAssertNil(LinkCleaner.parse("just-text"))
        XCTAssertNil(LinkCleaner.parse("ftp://example.com"))
    }

    func testKeepsUsefulParams() throws {
        let c = try XCTUnwrap(LinkCleaner.parse("https://youtube.com/watch?v=q8Tx0&si=abc"))
        XCTAssertEqual(c.url, "https://youtube.com/watch?v=q8Tx0")
        XCTAssertEqual(c.removed, ["si"])
    }

    func testNoStripWhenDisabled() throws {
        let c = try XCTUnwrap(LinkCleaner.parse("https://a.com/x?utm_source=1", strip: false))
        XCTAssertEqual(c.url, "https://a.com/x?utm_source=1")
        XCTAssertTrue(c.removed.isEmpty)
    }

    func testShortLinks() {
        XCTAssertTrue(LinkCleaner.isShortLink("t.co"))
        XCTAssertFalse(LinkCleaner.isShortLink("github.com"))
    }
}

final class FirestoreCodingTests: XCTestCase {
    func testRoundTrip() throws {
        var link = Link(cleaned: try XCTUnwrap(LinkCleaner.parse("https://github.com/apple/swift-collections?utm_source=x")),
                        title: "swift-collections", tags: ["swift", "reading"])
        link.note = "deques!"
        link.pinned = true
        let doc: [String: Any] = ["name": "projects/p/databases/(default)/documents/users/u/links/\(link.id)",
                                  "fields": Firestore.encode(link)]
        // Simulate JSON transport.
        let data = try JSONSerialization.data(withJSONObject: doc)
        let back = try XCTUnwrap(Firestore.decodeLink(try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])))
        XCTAssertEqual(back.id, link.id)
        XCTAssertEqual(back.url, link.url)
        XCTAssertEqual(back.tags, ["swift", "reading"])
        XCTAssertEqual(back.note, "deques!")
        XCTAssertTrue(back.pinned)
        XCTAssertEqual(back.trackersRemoved, ["utm_source"])
        XCTAssertEqual(back.createdAt.timeIntervalSince1970, link.createdAt.timeIntervalSince1970, accuracy: 0.01)
    }

    func testEmptyArrays() throws {
        let link = Link(cleaned: try XCTUnwrap(LinkCleaner.parse("https://a.com/b")))
        let doc: [String: Any] = ["name": "x/links/\(link.id)", "fields": Firestore.encode(link)]
        let back = try XCTUnwrap(Firestore.decodeLink(doc))
        XCTAssertEqual(back.tags, [])
    }
}

final class ImportExportTests: XCTestCase {
    func testParsesBookmarksHTML() {
        let html = """
        <DL><p><DT><A HREF="https://example.com/a?x=1&amp;y=2" ADD_DATE="1">Example &amp; Co</A>
        <DT><A HREF="javascript:void(0)">bad</A><DT><a href="https://b.org">B</a></DL>
        """
        let items = ImportExport.parse(html)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].url, "https://example.com/a?x=1&y=2")
        XCTAssertEqual(items[0].title, "Example & Co")
    }

    func testJSONRoundTrip() throws {
        let link = Link(cleaned: try XCTUnwrap(LinkCleaner.parse("https://a.com/b")), title: "A")
        let items = ImportExport.parse(ImportExport.json([link]))
        XCTAssertEqual(items.first?.url, "https://a.com/b")
        XCTAssertEqual(items.first?.title, "A")
    }

    func testMarkdown() throws {
        let link = Link(cleaned: try XCTUnwrap(LinkCleaner.parse("https://a.com/b")), title: "A", tags: ["x"])
        XCTAssertTrue(ImportExport.markdown([link]).contains("- [A](https://a.com/b) `#x`"))
    }
}

final class MiscTests: XCTestCase {
    func testVersionCompare() {
        XCTAssertTrue(Updates.isNewer("1.0.10", than: "1.0.9"))
        XCTAssertFalse(Updates.isNewer("1.0.9", than: "1.0.9"))
        XCTAssertFalse(Updates.isNewer("1.0", than: "1.0.1"))
    }

    func testPageTitle() {
        XCTAssertEqual(PageMeta.parseTitle("<html><head><title> Hello &amp; welcome </title></head>"), "Hello & welcome")
        XCTAssertEqual(PageMeta.parseTitle("<meta property=\"og:title\" content=\"OG Title\"><title>x</title>"), "OG Title")
    }

    func testRelativeTime() {
        let now = Date()
        XCTAssertEqual(RelativeTime.short(now, now: now), "Just now")
        XCTAssertEqual(RelativeTime.short(now.addingTimeInterval(-120), now: now), "2m")
        XCTAssertEqual(RelativeTime.short(now.addingTimeInterval(-7200), now: now), "2h")
    }

    func testInitials() {
        let a = Account(uid: "u", email: "sajid@gmail.com", name: "Sajid Rahman", provider: .google)
        XCTAssertEqual(a.initials, "SR")
        XCTAssertEqual(a.firstName, "Sajid")
    }
}
