import SwiftUI

struct PopoverView: View {
    @ObservedObject var ui: PopoverUI
    let actions: PopoverActions
    @ObservedObject private var store = Store.shared
    @ObservedObject private var prefs = Prefs.shared
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if ui.adding {
                AddLinkForm(prefill: store.clipboardLink?.original ?? "", compact: true,
                            onCancel: { ui.adding = false },
                            onDone: { ui.adding = false })
                    .padding(20)
            } else {
                main
            }
        }
        .frame(width: 380)
        .background(Tok.popoverBg)
        .overlay(alignment: .bottom) {
            if let t = store.toast { Toast(text: t).padding(.bottom, 56).transition(.opacity) }
        }
        .animation(.easeOut(duration: 0.18), value: store.toast)
        .animation(.easeOut(duration: 0.18), value: store.clipboardLink)
        .onChange(of: ui.focusSearch) { _ in searchFocused = true }
    }

    @ViewBuilder private var main: some View {
        if store.isSignedIn, store.syncStatus == .offline {
            Banner(icon: "cloud-off", text: "Offline · changes sync when you’re back", cta: "Retry") {
                Task { await store.syncNow() }
            }
        }
        if let c = store.clipboardLink {
            ClipboardCard(link: c, onStash: { store.stash(c) }, onDismiss: { store.dismissClipboard() })
                .padding(.bottom, 10)
        }
        HStack(spacing: 8) {
            SearchField(placeholder: store.active.isEmpty ? "Search stash" : "Search \(store.active.count) links",
                        text: $ui.query, focus: $searchFocused,
                        onSubmit: { if let first = store.recent(query: ui.query).first { store.open(first); actions.close() } })
            Button { ui.adding = true } label: {
                Icon(name: "plus", size: 18, color: Palette.ink)
                    .frame(width: 56, height: 40)
                    .background(RoundedRectangle(cornerRadius: Radius.control).fill(Palette.accent))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Add a link manually")
            .accessibilityLabel("Add a link")
        }
        .padding(.horizontal, 10)
        .padding(.top, store.clipboardLink == nil ? 10 : 0)

        content
        footer
    }

    @ViewBuilder private var content: some View {
        let list = store.recent(query: ui.query)
        if store.clipboardNotALink {
            PopoverEmpty(icon: "clipboard-x", title: "That’s not a link.",
                         message: "Stashbar only pins web addresses. Copy a URL and press \(HotKeys.quickStashLabel) again.",
                         primary: nil, secondary: ("Paste a URL instead", { store.clipboardNotALink = false; ui.adding = true }))
        } else if store.active.isEmpty {
            PopoverEmpty(icon: nil, title: "Nothing stashed yet.",
                         message: store.isSignedIn
                            ? "Copy any link and press \(prefs.openShortcut). It’ll be waiting here — and on every Mac you sign in to."
                            : "Links you stash stay on this Mac. Sign in anytime to back them up — nothing gets lost in the move.",
                         primary: ("Paste a URL", "link", { ui.adding = true }),
                         secondary: ("Import", { actions.close(); ImportExport.runImport() }))
        } else if list.isEmpty {
            PopoverEmpty(icon: "search-x", title: "No links match “\(ui.query)”.",
                         message: "Try a site name like figma.com, or a #tag.",
                         primary: ("Clear search", "eraser", { ui.query = "" }), secondary: nil)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: ui.query.isEmpty ? "Recent" : "Results")
                    .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 6)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(list) { link in
                            PopoverRow(link: link, onOpen: { store.open(link); actions.close() },
                                       onDetail: { actions.openDetail(link.id) })
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: CGFloat(min(list.count, 7)) * (prefs.compact ? 44 : 52) + 8)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let a = store.account {
                Avatar(account: a, size: 20)
                Text(store.syncLabel).font(12).foregroundColor(Tok.muted).lineLimit(1)
            } else {
                Avatar(account: nil, size: 20)
                Text("Guest · this Mac only").font(12).foregroundColor(Tok.muted)
                Button("Sign in", action: actions.signIn)
                    .buttonStyle(.plain).font(12).foregroundColor(Tok.text).underline()
            }
            Spacer()
            Button(action: actions.openCanvas) { Icon(name: "layout-grid", size: 15) }
                .buttonStyle(.plain).help("Open canvas (⌘E)").keyboardShortcut("e", modifiers: .command)
                .accessibilityLabel("Open canvas")
            Button(action: actions.openSettings) { Icon(name: "settings-2", size: 15) }
                .buttonStyle(.plain).help("Settings (⌘,)").keyboardShortcut(",", modifiers: .command)
                .padding(.leading, 6)
                .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 18)
        .frame(height: 42)
        .overlay(alignment: .top) { Rectangle().fill(Tok.line).frame(height: 1) }
    }
}

struct ClipboardCard: View {
    let link: CleanedLink
    var onStash: () -> Void
    var onDismiss: () -> Void

    // Full-width dark band. Text lines up with the "RECENT" label and link titles (18pt);
    // the button row uses the search row's geometry (10pt sides, 8pt gap, 56pt trailing button)
    // so "Stash it" sits over the search field and ✕ over the + button.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Icon(name: SiteLogo.icon(for: link.domain), size: 12, color: .white)
                Text("ON YOUR CLIPBOARD").font(12).foregroundColor(Palette.mutedOnDark)
                Spacer()
                if !link.removed.isEmpty {
                    Icon(name: "shield-check", size: 12, color: .white).opacity(0.7)
                    Text("\(link.removed.count) TRACKER\(link.removed.count == 1 ? "" : "S") OFF")
                        .font(12).foregroundColor(Palette.mutedOnDark)
                }
            }
            Text(link.guessedTitle).heading(18).foregroundColor(.white).lineLimit(2)
            Text(link.domain + Self.pathHint(link.url)).font(12).foregroundColor(Palette.mutedOnDark).lineLimit(1)
            }
            .padding(.horizontal, 18)
            HStack(spacing: 8) {
                Button(action: onStash) {
                    HStack(spacing: 8) {
                        PinMark(size: 16, color: Palette.ink)
                        Text("Stash it")
                        Icon(name: "corner-down-left", size: 13, color: Palette.ink).opacity(0.55)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(height: 40, fullWidth: true))
                .keyboardShortcut(.return, modifiers: [])
                Button(action: onDismiss) {
                    Icon(name: "x", size: 15, color: .white)
                        .frame(width: 56, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Palette.muted, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Dismiss (Esc)")
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, 10)
        }
        .padding(.top, 18)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.charcoal)
    }

    static func pathHint(_ url: String) -> String {
        guard let u = URL(string: url) else { return "" }
        let p = u.path
        return p.count > 1 ? String(p.prefix(40)) : ""
    }
}

struct PopoverRow: View {
    let link: Link
    var onOpen: () -> Void
    var onDetail: () -> Void
    @ObservedObject private var prefs = Prefs.shared
    @State private var hover = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                LogoTile(domain: link.domain, size: prefs.compact ? 26 : 32, iconSize: prefs.compact ? 13 : 15)
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title).font(13).foregroundColor(Tok.text).lineLimit(1)
                    Text("\(link.domain) · \(RelativeTime.short(link.createdAt))").font(12).foregroundColor(Tok.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if link.pinned { Icon(name: "pin", size: 12, color: Tok.muted) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, prefs.compact ? 6 : 9)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(hover ? Tok.surface : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(link.url)
        .contextMenu { LinkMenu(link: link, onDetail: onDetail) }
    }
}

/// Shared right-click menu for links.
struct LinkMenu: View {
    let link: Link
    var onDetail: (() -> Void)?
    var onDelete: (() -> Void)?
    private var store: Store { Store.shared }

    var body: some View {
        Button("Open") { store.open(link) }
        Button("Copy link") { store.copy(link) }
        if let onDetail { Button("Show details") { onDetail() } }
        Divider()
        Button(link.pinned ? "Unpin" : "Pin to top") { store.togglePin(link.id) }
        if link.archived {
            Button("Restore") { store.restore(link.id) }
        } else {
            Button("Archive") { store.archive(link.id) }
        }
        Divider()
        Button("Delete…") {
            if let onDelete { onDelete() } else { store.delete(link.id) }
        }
    }
}

struct PopoverEmpty: View {
    let icon: String?
    let title: String
    let message: String
    var primary: (String, String, () -> Void)?
    var secondary: (String, () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if let icon { Icon(name: icon, size: 22) } else { PinMark(size: 24) }
            }
            .frame(width: 48, height: 48)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
            Text(title).heading(24).foregroundColor(Tok.text).fixedSize(horizontal: false, vertical: true)
            Text(message).font(13).foregroundColor(Tok.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if let p = primary {
                    Button(action: p.2) {
                        HStack(spacing: 8) { Icon(name: p.1, size: 14, color: Palette.ink); Text(p.0) }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 42, fullWidth: true))
                }
                if let s = secondary {
                    Button(s.0, action: s.1).buttonStyle(OutlineButtonStyle(height: 42, fullWidth: true))
                }
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }
}

struct Banner: View {
    let icon: String
    let text: String
    var cta: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Icon(name: icon, size: 14, color: .white)
            Text(text).font(12).foregroundColor(.white)
            Spacer()
            if let cta, let action {
                Button(cta, action: action).buttonStyle(.plain).font(12).foregroundColor(Palette.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Palette.charcoal)
    }
}
