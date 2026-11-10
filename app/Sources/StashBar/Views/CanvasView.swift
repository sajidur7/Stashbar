import SwiftUI

struct CanvasRoot: View {
    @ObservedObject var nav: CanvasNav
    @ObservedObject private var store = Store.shared

    var body: some View {
        HStack(spacing: 0) {
            CanvasSidebar(nav: nav)
                .frame(width: 220)
            Group {
                if let id = nav.detailID, let link = store.link(id) {
                    LinkDetailView(link: link, nav: nav)
                } else {
                    CanvasMain(nav: nav)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tok.bg)
        }
        .ignoresSafeArea()
        .overlay {
            if nav.addingLink {
                DialogOverlay(onDismiss: { nav.addingLink = false }) {
                    AddLinkForm(prefill: nav.addPrefill, onCancel: { nav.addingLink = false }, onDone: { nav.addingLink = false })
                        .padding(28)
                        .frame(width: 460)
                        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Tok.bg))
                        .shadow(color: .black.opacity(0.3), radius: 35, y: 30)
                }
            }
            if let id = nav.confirmDeleteID, let link = store.link(id) {
                DialogOverlay(onDismiss: { nav.confirmDeleteID = nil }) {
                    DeleteLinkDialog(link: link, onClose: { nav.confirmDeleteID = nil }, onDeleted: {
                        if nav.detailID == id { nav.detailID = nil }
                    })
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let t = store.toast { Toast(text: t).padding(.bottom, 24).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(.easeOut(duration: 0.18), value: nav.addingLink)
        .animation(.easeOut(duration: 0.18), value: nav.confirmDeleteID)
        .animation(.easeOut(duration: 0.2), value: store.toast)
        .frame(minWidth: 820, minHeight: 520)
    }
}

// MARK: - Sidebar

struct CanvasSidebar: View {
    @ObservedObject var nav: CanvasNav
    @ObservedObject private var store = Store.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            TitlebarSpacer()
            HStack(spacing: 10) {
                PinMark(size: 20, color: Tok.sidebarText)
                Text("Stashbar").heading(18).foregroundColor(Tok.sidebarText)
            }
            .padding(.horizontal, 6)

            VStack(spacing: 2) {
                navRow(.all, icon: "library", count: store.active.count)
                navRow(.pinned, icon: "pin", count: store.pinned.count)
                navRow(.unopened, icon: "circle-dashed", count: store.unopened.count)
                navRow(.archive, icon: "archive", count: store.archived.count)
            }

            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: "Tags", color: Tok.sidebarMuted).padding(.horizontal, 12).padding(.bottom, 6)
                if store.tags.isEmpty {
                    Text("Tags appear here once you add them.").font(13).foregroundColor(Tok.sidebarMuted)
                        .padding(.horizontal, 12).fixedSize(horizontal: false, vertical: true)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            let tags = store.tags
                            ForEach(0..<tags.count, id: \.self) { i in
                                tagRow(tags[i].0, tags[i].1)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            accountCard
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity)
        .background(Tok.sidebarBg)
    }

    private func navRow(_ v: CanvasView, icon: String, count: Int) -> some View {
        let on = nav.view == v && nav.detailID == nil
        return Button {
            nav.view = v
            nav.detailID = nil
        } label: {
            HStack(spacing: 10) {
                Icon(name: icon, size: 15, color: on ? Palette.ink : Tok.sidebarText)
                Text(v.title).font(13, on ? .medium : .regular).foregroundColor(on ? Palette.ink : Tok.sidebarText)
                Spacer()
                Text("\(count)").font(12).foregroundColor(on ? Palette.ink : Tok.sidebarText).opacity(0.7)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(on ? Palette.accent : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tagRow(_ tag: String, _ count: Int) -> some View {
        let on = nav.view == .tag(tag)
        return Button {
            nav.view = .tag(tag)
            nav.detailID = nil
        } label: {
            HStack(spacing: 10) {
                Icon(name: "hash", size: 13, color: on ? Palette.ink : Tok.sidebarText).opacity(on ? 1 : 0.6)
                Text(tag).font(13).foregroundColor(on ? Palette.ink : Tok.sidebarText).lineLimit(1)
                Spacer()
                Text("\(count)").font(12).foregroundColor(on ? Palette.ink : Tok.sidebarMuted)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(on ? Palette.accent : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var accountCard: some View {
        if let a = store.account {
            Button { Windows.shared.showSettings(section: .account, from: .links) } label: {
                HStack(spacing: 10) {
                    Avatar(account: a, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(a.name.isEmpty ? a.email : a.name).font(13).foregroundColor(Tok.sidebarText).lineLimit(1)
                        Text(store.syncLabel.lowercased().replacingOccurrences(of: "synced ", with: "synced · "))
                            .font(12).foregroundColor(Tok.sidebarMuted).lineLimit(1).truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                    Icon(name: "settings-2", size: 14, color: Tok.sidebarMuted)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.sidebarCard))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Account & settings")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Avatar(account: nil, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Guest").font(13).foregroundColor(Tok.sidebarText)
                        Text("this Mac only").font(12).foregroundColor(Tok.sidebarMuted)
                    }
                    Spacer()
                    Button { Windows.shared.showSettings(section: .general, from: .links) } label: {
                        Icon(name: "settings-2", size: 14, color: Tok.sidebarMuted)
                    }.buttonStyle(.plain).help("Settings")
                }
                Button("Sign in to back up") { Windows.shared.showSettings(section: .account, from: .links) }
                    .buttonStyle(PrimaryButtonStyle(height: 34, fullWidth: true))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Tok.sidebarCard))
        }
    }
}

// MARK: - Main area

struct CanvasMain: View {
    @ObservedObject var nav: CanvasNav
    @ObservedObject private var store = Store.shared
    @ObservedObject private var prefs = Prefs.shared
    @FocusState private var searchFocused: Bool

    var body: some View {
        let list = store.links(for: nav.view, query: nav.query)
        VStack(alignment: .leading, spacing: 0) {
            if store.isSignedIn, store.syncStatus == .offline {
                Banner(icon: "cloud-off", text: "Offline · changes sync when you’re back", cta: "Retry") {
                    Task { await store.syncNow() }
                }
            }
            toolbar
            if store.links.isEmpty {
                FirstRunCanvas(signedIn: store.isSignedIn, name: store.account?.firstName,
                               onPaste: { nav.addPrefill = ""; nav.addingLink = true })
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(nav.view.title).heading(36).foregroundColor(Tok.text)
                    if nav.view == .archive {
                        Text("Hidden, not deleted").font(13).foregroundColor(Tok.muted)
                    } else if nav.view == .pinned {
                        Text("Always on top").font(13).foregroundColor(Tok.muted)
                    }
                    Spacer()
                    Text("\(list.count) · newest first").font(12).foregroundColor(Tok.muted)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)

                if list.isEmpty {
                    emptyState.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if nav.view == .archive {
                    ArchiveList(links: list, nav: nav)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                            ForEach(list) { link in
                                LinkCard(link: link, nav: nav)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .background {
            // Keyboard shortcuts for the canvas.
            Group {
                Button("") { searchFocused = true }.keyboardShortcut("k", modifiers: .command)
                Button("") { searchFocused = true }.keyboardShortcut("f", modifiers: .command)
                Button("") { nav.addPrefill = ""; nav.addingLink = true }.keyboardShortcut("n", modifiers: .command)
            }
            .opacity(0)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            SearchField(placeholder: store.links.isEmpty ? "Nothing to search yet" : "Search titles, sites, notes",
                        text: $nav.query, height: 42, token: tokenLabel,
                        onClearToken: { nav.view = .all }, focus: $searchFocused,
                        onSubmit: {
                            // "#design" in the search box becomes a tag filter.
                            let q = nav.query.trimmingCharacters(in: .whitespaces)
                            if q.hasPrefix("#"), q.count > 1, !q.contains(" ") {
                                nav.view = .tag(Store.normalizeTag(q))
                                nav.query = ""
                            }
                        })
            Button { ImportExport.export(store.links(for: nav.view, query: nav.query)) } label: {
                HStack(spacing: 8) { Icon(name: "share", size: 15); Text("Export") }
            }
            .buttonStyle(OutlineButtonStyle(height: 42))
            .disabled(store.links.isEmpty)
            .opacity(store.links.isEmpty ? 0.5 : 1)
            Button { nav.addPrefill = ""; nav.addingLink = true } label: {
                HStack(spacing: 8) { Icon(name: "plus", size: 15, color: Palette.ink); Text("Add link") }
            }
            .buttonStyle(PrimaryButtonStyle(height: 42))
            .help("Add link (⌘N)")
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 16)
    }

    private var tokenLabel: String? {
        switch nav.view {
        case .all: return nil
        case .pinned: return "pinned"
        case .unopened: return "unopened"
        case .archive: return "archive"
        case .tag(let t): return "#" + t
        }
    }

    @ViewBuilder private var emptyState: some View {
        if !nav.query.isEmpty {
            CanvasEmpty(icon: "search-x", title: "No links match “\(nav.query)”.",
                        message: "Try a site name like figma.com, or search inside notes and #tags.",
                        primary: ("Clear search", "eraser", { nav.query = "" }), secondary: nil)
        } else {
            switch nav.view {
            case .pinned:
                CanvasEmpty(icon: "pin", title: "No favourites pinned.",
                            message: "Press ⌘P on any link, or use the pin in a link’s detail view, to keep it at the top of the popover.",
                            primary: nil, secondary: ("Show all links", { nav.view = .all }))
            case .archive:
                CanvasEmpty(icon: "archive", title: "Archive is clear.",
                            message: "Links you archive rest here. Restore them anytime.",
                            primary: nil, secondary: ("Back to stash", { nav.view = .all }))
            case .unopened:
                CanvasEmpty(icon: "circle-dashed", title: "You’ve opened everything.",
                            message: "Links you stash but never open collect here.",
                            primary: nil, secondary: ("Show all links", { nav.view = .all }))
            case .tag(let t):
                CanvasEmpty(icon: "hash", title: "Nothing tagged #\(t) yet.",
                            message: "Add tags while stashing, or from a link’s detail view.",
                            primary: ("Browse all links", "library", { nav.view = .all }), secondary: nil)
            case .all:
                CanvasEmpty(icon: "archive", title: "Everything is archived.",
                            message: "Restore links from the Archive to see them here.",
                            primary: nil, secondary: ("Open archive", { nav.view = .archive }))
            }
        }
    }
}

struct CanvasEmpty: View {
    let icon: String
    let title: String
    let message: String
    var primary: (String, String, () -> Void)?
    var secondary: (String, () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Icon(name: icon, size: 24)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
            Text(title).heading(28).foregroundColor(Tok.text)
            Text(message).font(13).foregroundColor(Tok.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if let p = primary {
                    Button(action: p.2) { HStack(spacing: 8) { Icon(name: p.1, size: 14, color: Palette.ink); Text(p.0) } }
                        .buttonStyle(PrimaryButtonStyle(height: 42))
                }
                if let s = secondary { Button(s.0, action: s.1).buttonStyle(OutlineButtonStyle(height: 42)) }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: 380, alignment: .leading)
        .padding(28)
    }
}

/// 3r / 3u — the canvas before the first link.
struct FirstRunCanvas: View {
    let signedIn: Bool
    let name: String?
    var onPaste: () -> Void
    @ObservedObject private var prefs = Prefs.shared

    var body: some View {
        if signedIn {
            VStack(spacing: 22) {
                Artwork(name: "app-icon-accent", size: 96)
                VStack(spacing: 10) {
                    Text("No links stashed yet.").heading(36).foregroundColor(Tok.text)
                    Text("Copy a link anywhere and press \(prefs.openShortcut). Links you stash on any Mac signed in as \(name ?? "you") show up here.")
                        .font(16).foregroundColor(Tok.muted).multilineTextAlignment(.center).frame(maxWidth: 460)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    Button(action: onPaste) { HStack(spacing: 8) { Icon(name: "link", size: 15, color: Palette.ink); Text("Paste a URL") } }
                        .buttonStyle(PrimaryButtonStyle(height: 46)).frame(width: 190)
                    Button { ImportExport.runImport() } label: { HStack(spacing: 8) { Icon(name: "import", size: 15); Text("Import bookmarks").font(14) } }
                        .buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true)).frame(width: 190)
                }
                HStack(spacing: 8) {
                    Text("Quick stash from any app").font(13).foregroundColor(Tok.muted)
                    KeyCap(icon: nil, label: prefs.openShortcut, height: 24)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Tok.sand, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            .padding(.horizontal, 24).padding(.bottom, 24)
        } else {
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 18) {
                    PinMark(size: 56)
                    Text("Your canvas is waiting.").heading(44).foregroundColor(Tok.text).fixedSize(horizontal: false, vertical: true)
                    Text("Pinned links show up here as cards, sorted by when you saved them. Three ways to add your first:")
                        .font(14).foregroundColor(Tok.muted).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 10) {
                    way(icon: "copy", title: "Copy a link, then press \(prefs.openShortcut)", hint: "From any app — it’s pinned in one keystroke",
                        key: prefs.openShortcut, bg: Tok.surface, action: nil)
                    way(icon: "link", title: "Paste a URL", hint: "Drop an address straight in", key: "⌘V", bg: Palette.accent, action: onPaste)
                    way(icon: "import", title: "Import bookmarks", hint: "Safari, Chrome, Arc or an HTML file", key: "Import",
                        bg: Tok.surface, action: { ImportExport.runImport() })
                }
                .frame(maxWidth: .infinity)
            }
            .padding(56)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func way(icon: String, title: String, hint: String, key: String, bg: Color, action: (() -> Void)?) -> some View {
        let isAccent = bg == Palette.accent
        let row = HStack(spacing: 14) {
            Icon(name: icon, size: 18, color: Palette.ink)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Color.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(14).foregroundColor(isAccent ? Palette.ink : Tok.text)
                Text(hint).font(13).foregroundColor(isAccent ? Palette.graphite : Tok.muted)
            }
            Spacer()
            Text(key).font(12).foregroundColor(Palette.ink)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: Radius.small).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: Radius.small).strokeBorder(Palette.line, lineWidth: 1))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(bg))
        .contentShape(Rectangle())
        return Group {
            if let action { Button(action: action) { row }.buttonStyle(.plain) } else { row }
        }
    }
}

// MARK: - Cards

struct LinkCard: View {
    let link: Link
    @ObservedObject var nav: CanvasNav
    @ObservedObject private var prefs = Prefs.shared
    @State private var hover = false
    @State private var preview: NSImage?

    var body: some View {
        Button { nav.detailID = link.id } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Tok.surface
                        if prefs.linkPreviews, let preview {
                            Image(nsImage: preview).resizable().scaledToFill()
                        } else {
                            Icon(name: SiteLogo.icon(for: link.domain), size: 30)
                        }
                    }
                    .frame(height: 96)
                    .clipped()
                    if link.pinned {
                        Icon(name: "pin", size: 12, color: Palette.ink)
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Palette.accent))
                            .padding(8)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(link.title).font(13).foregroundColor(Tok.text).lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
                    HStack(spacing: 6) {
                        Text("\(link.domain) · \(RelativeTime.short(link.createdAt))")
                            .font(12).foregroundColor(Tok.muted).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        IconButton(icon: "archive", help: "Archive") { Store.shared.archive(link.id) }
                        IconButton(icon: "trash-2", help: "Delete") { nav.confirmDeleteID = link.id }
                    }
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 14, trailing: 14))
            }
            .background(Tok.bg)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(hover ? Tok.sand : Tok.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: Radius.card))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .contextMenu { LinkMenu(link: link, onDetail: { nav.detailID = link.id }, onDelete: { nav.confirmDeleteID = link.id }) }
        .task(id: link.previewImageURL) {
            if prefs.linkPreviews, let u = link.previewImageURL { preview = await PreviewCache.image(for: u) }
        }
    }
}

struct ArchiveList: View {
    let links: [Link]
    @ObservedObject var nav: CanvasNav
    private var store: Store { Store.shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Icon(name: "info", size: 14, color: Tok.muted)
                    Text("Archived links are hidden from search and the popover. Restore puts them back in All links.")
                        .font(13).foregroundColor(Tok.muted)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
                ForEach(links) { link in
                    HStack(spacing: 12) {
                        LogoTile(domain: link.domain, size: 40, iconSize: 17)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.title).font(13).foregroundColor(Tok.text).lineLimit(1)
                            Text("\(link.domain) · archived \(RelativeTime.short(link.updatedAt))").font(12).foregroundColor(Tok.muted)
                        }
                        Spacer()
                        Button { store.restore(link.id) } label: {
                            HStack(spacing: 6) { Icon(name: "archive-restore", size: 14, color: Palette.ink); Text("Restore") }
                        }
                        .buttonStyle(PrimaryButtonStyle(height: 34))
                        IconButton(icon: "trash-2", size: 34, iconSize: 14, help: "Delete forever") { nav.confirmDeleteID = link.id }
                    }
                    .padding(12)
                    .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Tok.line, lineWidth: 1))
                    .contentShape(Rectangle())
                    .onTapGesture { nav.detailID = link.id }
                    .contextMenu { LinkMenu(link: link, onDetail: { nav.detailID = link.id }, onDelete: { nav.confirmDeleteID = link.id }) }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

struct DeleteLinkDialog: View {
    let link: Link
    var onClose: () -> Void
    var onDeleted: () -> Void

    var body: some View {
        DialogCard {
            Icon(name: "trash-2", size: 22, color: .white)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Palette.charcoal))
            VStack(alignment: .leading, spacing: 8) {
                Text("Delete this link?").heading(28).foregroundColor(Tok.text)
                Text("“\(link.title)” will be removed\(Store.shared.isSignedIn ? " from every Mac" : ""). Archive it instead if you might want it later.")
                    .font(13).foregroundColor(Tok.muted).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button("Cancel", action: onClose).buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true))
                    .keyboardShortcut(.cancelAction)
                if !link.archived {
                    Button("Archive") { Store.shared.archive(link.id); onClose() }
                        .buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true))
                }
                Button("Delete") {
                    Store.shared.delete(link.id)
                    Store.shared.celebrate("Deleted")
                    onDeleted()
                    onClose()
                }
                .buttonStyle(DarkButtonStyle(height: 46, fullWidth: true))
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
