import SwiftUI

struct SettingsRoot: View {
    @ObservedObject var nav: SettingsNav
    @ObservedObject private var store = Store.shared

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(nav: nav).frame(width: 250)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(nav.section.title).heading(36).foregroundColor(Tok.text)
                        Text(nav.section.subtitle).font(14).foregroundColor(Tok.muted)
                    }
                    .padding(.top, 44).padding(.bottom, 24)
                    pane
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 40)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Tok.bg)
        }
        .ignoresSafeArea()
        .overlay { dialog }
        .overlay(alignment: .bottom) {
            if let t = store.toast { Toast(text: t).padding(.bottom, 24) }
        }
        .animation(.easeOut(duration: 0.18), value: nav.dialog)
        .animation(.easeOut(duration: 0.2), value: store.toast)
    }

    @ViewBuilder private var pane: some View {
        switch nav.section {
        case .account: AccountPane(nav: nav)
        case .general: GeneralPane()
        case .onboarding: OnboardingPane()
        case .shortcuts: ShortcutsPane()
        case .cleaning: CleaningPane()
        case .appearance: AppearancePane()
        case .data: DataPane()
        case .about: AboutPane()
        }
    }

    @ViewBuilder private var dialog: some View {
        if let d = nav.dialog {
            DialogOverlay(onDismiss: d == .deleted ? nil : { nav.dialog = nil }) {
                switch d {
                case .signOutConfirm: SignOutConfirmDialog(nav: nav)
                case .signedOut: SignedOutDialog(nav: nav)
                case .deleteConfirm: DeleteAccountDialog(nav: nav)
                case .deleted: AccountDeletedDialog(nav: nav)
                case .photo: ProfilePhotoDialog(nav: nav)
                }
            }
        }
    }
}

struct SettingsSidebar: View {
    @ObservedObject var nav: SettingsNav
    @ObservedObject private var store = Store.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TitlebarSpacer()
            Button { Windows.shared.closeSettingsAndGoBack() } label: {
                HStack(spacing: 6) {
                    Icon(name: "arrow-left", size: 15, color: Tok.sidebarText)
                    Text(backLabel).font(14, .medium).foregroundColor(Tok.sidebarText)
                    Spacer()
                    Text("esc").font(12).foregroundColor(Tok.sidebarMuted)
                        .padding(.horizontal, 6).frame(height: 22)
                        .overlay(RoundedRectangle(cornerRadius: Radius.small).strokeBorder(Tok.sidebarLine, lineWidth: 1))
                }
                .padding(.leading, 6).padding(.trailing, 8).frame(height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            Button { nav.section = .account } label: {
                HStack(spacing: 12) {
                    if let a = store.account {
                        Avatar(account: a, size: 40)
                    } else {
                        Avatar(account: nil, size: 40)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.account.map { $0.name.isEmpty ? $0.email : $0.name } ?? "Guest")
                            .font(13).foregroundColor(Tok.sidebarText).lineLimit(1)
                        Text(store.account?.email ?? "this Mac only").font(12).foregroundColor(Tok.sidebarMuted)
                            .lineLimit(1).truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.sidebarCard))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                ForEach(SettingsSection.allCases) { s in
                    let on = nav.section == s
                    Button { nav.section = s } label: {
                        HStack(spacing: 10) {
                            Icon(name: s.icon, size: 15, color: on ? Palette.ink : Tok.sidebarText)
                            Text(s.title).font(13, on ? .medium : .regular).foregroundColor(on ? Palette.ink : Tok.sidebarText)
                            Spacer()
                            if s == .account && store.isGuest {
                                Circle().fill(Palette.accent).frame(width: 7, height: 7)
                            }
                        }
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: Radius.control).fill(on ? Palette.accent : Color.clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                PinMark(size: 13, color: Tok.sidebarMuted)
                Text("Stashbar \(Config.appVersion)").font(12).foregroundColor(Tok.sidebarMuted)
            }
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 12).padding(.bottom, 16)
        .frame(maxHeight: .infinity)
        .background(Tok.sidebarBg)
    }

    private var backLabel: String {
        switch nav.back {
        case .links: return "Back to links"
        case .popover: return "Back to popover"
        case .link: return "Back to link"
        }
    }
}

// MARK: - Row building blocks

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: title).padding(.bottom, 8)
            content
        }
        .padding(.bottom, 28)
    }
}

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let label: String
    let hint: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            Icon(name: icon, size: 16)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(13).foregroundColor(Tok.text)
                Text(hint).font(13).foregroundColor(Tok.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(Tok.line).frame(height: 1) }
    }
}

struct RowButton: View {
    let title: String
    var icon: String?
    var primary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Icon(name: icon, size: 14, color: primary ? Palette.ink : Tok.text) }
                Text(title).font(13)
            }
        }
        .buttonStyle(primary ? AnyButtonStyle(PrimaryButtonStyle(height: 36)) : AnyButtonStyle(OutlineButtonStyle(height: 36)))
        .fixedSize()
    }
}

// MARK: - Panes

struct AccountPane: View {
    @ObservedObject var nav: SettingsNav
    @ObservedObject private var store = Store.shared
    @ObservedObject private var prefs = Prefs.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let a = store.account {
                HStack(spacing: 18) {
                    Button { nav.dialog = .photo } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Avatar(account: a, size: 64)
                            Icon(name: "camera", size: 12, color: Palette.ink)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Palette.accent))
                                .overlay(Circle().strokeBorder(Tok.surface, lineWidth: 2))
                                .offset(x: 2, y: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Change profile photo")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.name.isEmpty ? a.firstName : a.name).heading(22).foregroundColor(Tok.text)
                        Text("\(a.email) · Signed in with \(a.provider.label)").font(13).foregroundColor(Tok.muted)
                    }
                    Spacer()
                    Button { Task { await store.syncNow() } } label: {
                        HStack(spacing: 6) {
                            Icon(name: store.syncStatus == .offline ? "cloud-off" : "refresh-cw", size: 13)
                            Text(store.syncLabel).font(12, .medium).foregroundColor(Tok.text)
                        }
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.bg))
                    }
                    .buttonStyle(.plain)
                    .help("Sync now")
                }
                .padding(22)
                .background(RoundedRectangle(cornerRadius: Radius.card).fill(Tok.surface))

                if case .error(let m) = store.syncStatus {
                    Text("Sync problem: \(m)").font(12).foregroundColor(Tok.muted)
                }

                HStack(spacing: 10) {
                    stat("\(store.links.count)", "links")
                    stat("\(store.tags.count)", "tags")
                    stat("\(max(store.devices.count, 1))", store.devices.count == 1 ? "Mac" : "Macs")
                }

                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "Sync").padding(.bottom, 8)
                    plainRow("Sync automatically", "Keep every signed-in Mac up to date") { PillToggle(isOn: $prefs.autoSync) }
                }

                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "Devices").padding(.bottom, 8)
                    ForEach(store.devices) { d in
                        HStack(spacing: 12) {
                            Icon(name: d.model.lowercased().contains("book") ? "laptop" : "monitor", size: 17)
                            Text(d.name + (d.id == prefs.deviceID ? " — this Mac" : "")).font(13).foregroundColor(Tok.text)
                            Spacer()
                            Text(d.id == prefs.deviceID ? "now" : RelativeTime.long(d.lastSeen)).font(12).foregroundColor(Tok.muted)
                        }
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) { Rectangle().fill(Tok.line).frame(height: 1) }
                    }
                    if store.devices.isEmpty {
                        Text("This Mac").font(13).foregroundColor(Tok.muted).padding(.vertical, 12)
                            .overlay(alignment: .top) { Rectangle().fill(Tok.line).frame(height: 1) }
                    }
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign out of Stashbar").font(13).foregroundColor(Tok.text)
                        Text("A copy of your \(store.links.count) links can stay on this Mac. Sign back in anytime.")
                            .font(13).foregroundColor(Tok.muted)
                    }
                    Spacer()
                    Button { nav.dialog = .signOutConfirm } label: {
                        HStack(spacing: 8) { Icon(name: "log-out", size: 14); Text("Sign out") }
                    }
                    .buttonStyle(OutlineButtonStyle(height: 42))
                }
                .padding(.horizontal, 20).padding(.vertical, 18)
                .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Tok.line, lineWidth: 1))

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete account and all links").font(13).foregroundColor(Tok.text)
                        Text("Removes everything from our servers and every Mac. Can’t be undone.").font(13).foregroundColor(Tok.muted)
                    }
                    Spacer()
                    Button("Delete account") { nav.dialog = .deleteConfirm }
                        .buttonStyle(.plain).font(13).foregroundColor(Tok.text).underline()
                }
                .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Icon(name: "triangle-alert", size: 13, color: Palette.accent)
                        Text("GUEST · NOT BACKED UP").font(12).foregroundColor(Palette.accent)
                    }
                    Text(store.links.isEmpty ? "Nothing to lose yet." : "\(store.links.count) link\(store.links.count == 1 ? "" : "s") live only on this Mac.")
                        .heading(28).foregroundColor(.white)
                    Text("If you delete Stashbar they’re gone, and a new install starts empty. Sign in to move them all to your account.")
                        .font(13).foregroundColor(Palette.mutedOnDark).fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.card).fill(Palette.charcoal))

                SignInButtons(height: 48, sideBySide: true, onSignedIn: {
                    store.celebrate("Signed in — your links are backed up")
                })

                HStack(spacing: 10) {
                    Icon(name: "download", size: 14, color: Tok.muted)
                    Text("Rather stay a guest? Keep a manual backup.").font(13).foregroundColor(Tok.muted)
                    Spacer()
                    Button("Export .json") { ImportExport.export(store.links, format: .json) }
                        .buttonStyle(.plain).font(13).foregroundColor(Tok.text).underline()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
            }
        }
    }

    private func stat(_ v: String, _ k: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(v).heading(28).foregroundColor(Tok.text)
            Text(k).font(12).foregroundColor(Tok.muted)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Tok.line, lineWidth: 1))
    }

    private func plainRow<T: View>(_ label: String, _ hint: String, @ViewBuilder _ trailing: () -> T) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(13).foregroundColor(Tok.text)
                Text(hint).font(13).foregroundColor(Tok.muted)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(Tok.line).frame(height: 1) }
    }
}

struct GeneralPane: View {
    @ObservedObject private var prefs = Prefs.shared
    @State private var launch = Prefs.shared.launchAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "Startup") {
                SettingsRow(icon: "power", label: "Launch at login", hint: "Keep Stashbar ready in the menu bar") {
                    PillToggle(isOn: Binding(get: { launch }, set: { launch = $0; prefs.launchAtLogin = $0 }))
                }
                SettingsRow(icon: "app-window", label: "Show in Dock", hint: "Off keeps Stashbar menu-bar only") {
                    PillToggle(isOn: $prefs.showInDock)
                }
            }
            SettingsGroup(title: "Behaviour") {
                SettingsRow(icon: "clipboard", label: "Watch clipboard for links", hint: "Offers to stash links you copy. Checked on this Mac only.") {
                    PillToggle(isOn: $prefs.watchClipboard)
                }
                SettingsRow(icon: "volume-2", label: "Play sound when stashed", hint: "A soft pop confirms each stash") {
                    PillToggle(isOn: $prefs.playSound)
                }
                SettingsRow(icon: "rows-3", label: "Popover shows", hint: "Most recent links in the menu-bar popover") {
                    Segmented(options: ["5", "10", "20"], selection: $prefs.popoverCount)
                }
            }
            SettingsGroup(title: "Quit") {
                SettingsRow(icon: "log-out", label: "Quit Stashbar", hint: "Removes the menu-bar icon and stops watching the clipboard. Also: right-click the menu-bar icon → Quit.") {
                    RowButton(title: "Quit", icon: nil) { NSApp.terminate(nil) }
                }
            }
        }
    }
}

struct OnboardingPane: View {
    @ObservedObject private var prefs = Prefs.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "First-run") {
                SettingsRow(icon: "graduation-cap", label: "Show welcome tour on new Macs", hint: "Runs once on each Mac you sign in to") {
                    PillToggle(isOn: $prefs.tourOnNewMacs)
                }
                SettingsRow(icon: "lightbulb", label: "Inline tips", hint: "Small hints like “Type #tag in search to filter”") {
                    PillToggle(isOn: $prefs.inlineTips)
                }
            }
            SettingsGroup(title: "Reset") {
                SettingsRow(icon: "rotate-ccw", label: "Reset dismissed tips", hint: "Bring back every hint you closed") {
                    RowButton(title: "Reset tips") { prefs.resetTips(); Store.shared.celebrate("Tips reset") }
                }
            }
            HStack(spacing: 18) {
                Artwork(name: "app-icon-accent", size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Replay the welcome tour").heading(18).foregroundColor(.white)
                    Text("Walk through setup again. Your links and account aren’t touched.").font(13).foregroundColor(Palette.mutedOnDark)
                }
                Spacer()
                Button { Windows.shared.showOnboarding(replay: true) } label: {
                    HStack(spacing: 8) { Icon(name: "play", size: 14, color: Palette.ink); Text("Start tour") }
                }
                .buttonStyle(PrimaryButtonStyle(height: 42))
            }
            .padding(.horizontal, 22).padding(.vertical, 20)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Palette.charcoal))
        }
    }
}

struct ShortcutsPane: View {
    @ObservedObject private var prefs = Prefs.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "Global") {
                SettingsRow(icon: "panel-top-open", label: "Open Stashbar", hint: "From any app") {
                    Menu {
                        ForEach(HotKeys.options, id: \.self) { o in Button(o) { prefs.openShortcut = o } }
                    } label: { KeyCap(label: prefs.openShortcut) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .help("Click to change")
                }
                SettingsRow(icon: "clipboard-paste", label: "Stash clipboard instantly", hint: "Skips the popover") {
                    KeyCap(label: shifted)
                }
            }
            SettingsGroup(title: "In Stashbar") {
                SettingsRow(icon: "layout-grid", label: "Open canvas", hint: "Full window with every link") { KeyCap(icon: "command", label: "E") }
                SettingsRow(icon: "plus", label: "Add a link", hint: "In the canvas") { KeyCap(icon: "command", label: "N") }
                SettingsRow(icon: "search", label: "Search", hint: "In the canvas") { KeyCap(icon: "command", label: "K") }
                SettingsRow(icon: "pin", label: "Pin to top", hint: "In a link’s detail view") { KeyCap(icon: "command", label: "P") }
                SettingsRow(icon: "settings-2", label: "Settings", hint: "From anywhere in Stashbar") { KeyCap(icon: "command", label: ",") }
            }
        }
    }

    private var shifted: String {
        let s = prefs.openShortcut
        return s.contains("⇧") ? s : s.replacingOccurrences(of: "S", with: "⇧S")
    }
}

struct CleaningPane: View {
    @ObservedObject private var prefs = Prefs.shared
    @State private var newParam = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "Cleaning") {
                SettingsRow(icon: "shield-check", label: "Strip tracking parameters", hint: "utm_, fbclid, si and \(prefs.trackerList.count - 3) more") {
                    PillToggle(isOn: $prefs.stripTrackers)
                }
                SettingsRow(icon: "copy", label: "Copy the clean URL", hint: "Otherwise copies the original link") {
                    PillToggle(isOn: $prefs.copyClean)
                }
                SettingsRow(icon: "maximize-2", label: "Expand short links", hint: "t.co, bit.ly and friends become the real address") {
                    PillToggle(isOn: $prefs.expandShortLinks)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "Always strip these parameters")
                    Spacer()
                    Button("Restore defaults") { prefs.trackerList = LinkCleaner.defaultTrackers }
                        .buttonStyle(.plain).font(12).foregroundColor(Tok.muted).underline()
                }
                WrapLayout(spacing: 6) {
                    ForEach(prefs.trackerList, id: \.self) { t in
                        HStack(spacing: 6) {
                            Text(t).font(12).foregroundColor(Tok.text)
                            Button { prefs.trackerList.removeAll { $0 == t } } label: { Icon(name: "x", size: 10, color: Tok.muted) }
                                .buttonStyle(.plain).help("Stop stripping \(t)")
                        }
                        .padding(.leading, 12).padding(.trailing, 8).frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
                    }
                    HStack(spacing: 6) {
                        Icon(name: "plus", size: 12, color: Tok.muted)
                        TextField("", text: $newParam, prompt: Text("Add parameter").foregroundColor(Tok.muted))
                            .textFieldStyle(.plain).font(12).frame(width: 110)
                            .onSubmit {
                                let p = newParam.trimmingCharacters(in: .whitespaces)
                                if !p.isEmpty && !prefs.trackerList.contains(p) { prefs.trackerList.append(p) }
                                newParam = ""
                            }
                    }
                    .padding(.horizontal, 12).frame(height: 30)
                    .overlay(RoundedRectangle(cornerRadius: Radius.control)
                        .strokeBorder(Palette.mutedOnDark, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                }
                Text("Use * at the end to match a prefix, like utm_*.").font(12).foregroundColor(Tok.muted)
            }
        }
    }
}

struct AppearancePane: View {
    @ObservedObject private var prefs = Prefs.shared
    var body: some View {
        SettingsGroup(title: "Look") {
            SettingsRow(icon: "sun-moon", label: "Theme", hint: "Follows macOS by default") {
                Segmented(options: ["Light", "Dark", "System"], selection: $prefs.theme)
            }
            SettingsRow(icon: "rows-3", label: "Density", hint: "Row height in lists") {
                Segmented(options: ["Compact", "Comfortable"], selection: $prefs.density)
            }
            SettingsRow(icon: "pin", label: "Menu-bar icon", hint: "What appears next to the clock") {
                Segmented(options: ["Pin", "Pin + count"], selection: $prefs.menuIcon)
            }
            SettingsRow(icon: "image", label: "Show link previews", hint: "Load page images in the canvas") {
                PillToggle(isOn: $prefs.linkPreviews)
            }
        }
    }
}

struct DataPane: View {
    @ObservedObject private var store = Store.shared
    @State private var cacheSize = Storage.cacheSize()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "Your links") {
                SettingsRow(icon: "import", label: "Import bookmarks", hint: "Safari, Chrome, Arc or Firefox bookmarks file, or a Stashbar .json") {
                    RowButton(title: "Import…") { ImportExport.runImport() }
                }
                SettingsRow(icon: "download", label: "Export everything", hint: "JSON, Markdown or browser bookmarks") {
                    RowButton(title: "Export…", primary: true) { ImportExport.export(store.links) }
                }
            }
            SettingsGroup(title: "Privacy") {
                SettingsRow(icon: "lock", label: "What leaves your Mac",
                            hint: store.isSignedIn
                                ? "Only the links you stash (URL, title, tags, notes) — stored in your private account. Never clipboard text or browsing history."
                                : "Nothing. As a guest, your links are stored only on this Mac.") { EmptyView() }
                SettingsRow(icon: "trash-2", label: "Clear local cache",
                            hint: "Frees \(ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)) of previews. Links are kept.") {
                    RowButton(title: "Clear cache") {
                        Storage.clearCache()
                        cacheSize = Storage.cacheSize()
                        store.celebrate("Cache cleared")
                    }
                }
            }
        }
    }
}

struct AboutPane: View {
    @State private var status = "Up to date"
    @State private var checking = false
    @State private var updateURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 22) {
                Artwork(name: "app-icon-dark", size: 88)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stashbar").heading(28).foregroundColor(Tok.text)
                    Text("Version \(Config.appVersion) (\(Config.buildNumber)) · \(status)").font(13).foregroundColor(Tok.muted)
                }
                Spacer()
                if let updateURL {
                    Button { NSWorkspace.shared.open(updateURL) } label: {
                        HStack(spacing: 8) { Icon(name: "download", size: 14, color: Palette.ink); Text("Download update") }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 40))
                } else {
                    Button { check() } label: {
                        HStack(spacing: 8) {
                            if checking { ProgressView().controlSize(.small) } else { Icon(name: "refresh-cw", size: 14) }
                            Text("Check for updates")
                        }
                    }
                    .buttonStyle(OutlineButtonStyle(height: 40))
                    .disabled(checking)
                }
            }
            .padding(26)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Tok.surface))

            VStack(spacing: 0) {
                aboutLink("book-open", "Help & keyboard guide", Config.helpPage)
                aboutLink("file-text", "Privacy policy", Config.privacyPage)
                aboutLink("github", "Source on GitHub", Config.repo)
                aboutLink("mail", "Email us", URL(string: "mailto:incognitoshimul@gmail.com?subject=Stashbar")!)
            }
        }
        .onAppear { check() }
    }

    private func check() {
        checking = true
        status = "Checking…"
        Task {
            let r = await Updates.check()
            checking = false
            if let r {
                if r.newer { status = "Version \(r.latest) available"; updateURL = r.url } else { status = "Up to date" }
            } else {
                status = "Couldn’t check"
            }
        }
    }

    private func aboutLink(_ icon: String, _ label: String, _ url: URL) -> some View {
        Button { NSWorkspace.shared.open(url) } label: {
            HStack(spacing: 14) {
                Icon(name: icon, size: 16)
                Text(label).font(13).foregroundColor(Tok.text)
                Spacer()
                Icon(name: "arrow-up-right", size: 14, color: Tok.muted)
            }
            .padding(.vertical, 14)
            .overlay(alignment: .top) { Rectangle().fill(Tok.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
