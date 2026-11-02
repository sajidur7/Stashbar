import SwiftUI

@MainActor
final class OnboardingModel: ObservableObject {
    enum Step { case welcome, signIn, guestConfirm, restoring, shortcut, done }
    @Published var step: Step = .welcome
    @Published var replay = false

    func reset(replay: Bool) {
        self.replay = replay
        step = .welcome
    }

    var dotIndex: Int {
        switch step {
        case .welcome: return 0
        case .signIn, .guestConfirm, .restoring: return 1
        case .shortcut: return 2
        case .done: return 3
        }
    }
}

struct OnboardingRoot: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var store = Store.shared

    var body: some View {
        Group {
            switch model.step {
            case .welcome: WelcomeStep(model: model)
            case .signIn: SignInStep(model: model)
            case .guestConfirm: GuestConfirmStep(model: model)
            case .restoring: RestoreStep(model: model)
            case .shortcut: ShortcutStep(model: model)
            case .done: DoneStep(model: model)
            }
        }
        .frame(width: 480, height: 620)
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.2), value: model.step)
    }
}

private struct StepDots: View {
    let index: Int
    var dark = true
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i == index ? Palette.accent : (dark ? Palette.graphite : Tok.sand))
                    .frame(width: i == index ? 22 : 6, height: 6)
            }
        }
        .accessibilityLabel("Step \(index + 1) of 4")
    }
}

private struct StepLabel: View {
    let text: String
    var body: some View { Text(text).font(12).foregroundColor(Tok.muted) }
}

// 3b
struct WelcomeStep: View {
    @ObservedObject var model: OnboardingModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 28)
            Artwork(name: "app-icon-accent", size: 96)
            Text("Stop losing\ngood links.").heading(44).foregroundColor(.white)
            Text("Stashbar lives in your menu bar. Copy a link anywhere, press \(Prefs.shared.openShortcut), and it’s pinned — trackers stripped, ready to find.")
                .font(16).foregroundColor(Palette.mutedOnDark).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack {
                StepDots(index: 0)
                Spacer()
                Button { model.step = Store.shared.isSignedIn ? .shortcut : .signIn } label: {
                    HStack(spacing: 8) { Text("Get started"); Icon(name: "arrow-right", size: 16, color: Palette.ink) }
                }
                .buttonStyle(PrimaryButtonStyle(height: 44))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 40).padding(.bottom, 40).padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.charcoal)
    }
}

// 3c
struct SignInStep: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var store = Store.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 28)
            StepLabel(text: "STEP 2 OF 4")
            VStack(alignment: .leading, spacing: 12) {
                Text("Keep your links for good.").heading(36).foregroundColor(Tok.text)
                Text("Sign in to back up your stash and sync it across Macs. Reinstall anytime — everything comes back.")
                    .font(14).foregroundColor(Tok.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            SignInButtons(onSignedIn: { model.step = store.active.isEmpty ? .shortcut : .restoring })
            HStack(spacing: 12) {
                Rectangle().fill(Tok.sand).frame(height: 1)
                Text("OR").font(12).foregroundColor(Tok.muted)
                Rectangle().fill(Tok.sand).frame(height: 1)
            }
            Button { model.step = .guestConfirm } label: {
                HStack(spacing: 10) { Icon(name: "user-round", size: 16); Text("Continue as guest") }
            }
            .buttonStyle(SoftButtonStyle(height: 50, fullWidth: true))
            .disabled(store.signingIn)
            Spacer()
            HStack(alignment: .top, spacing: 8) {
                Icon(name: "lock", size: 14).opacity(0.6).padding(.top, 2)
                Text("We store the links you pin — never your browsing history.").font(13).foregroundColor(Tok.muted)
            }
        }
        .padding(.horizontal, 40).padding(.bottom, 36).padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tok.bg)
    }
}

/// Apple + Google buttons with progress and error states. Shared by onboarding and Settings.
struct SignInButtons: View {
    var height: CGFloat = 50
    var sideBySide = false
    var onSignedIn: () -> Void
    @ObservedObject private var store = Store.shared
    @State private var pending: AuthProvider?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let layout = sideBySide ? AnyLayout(HStackLayout(spacing: 10)) : AnyLayout(VStackLayout(spacing: 10))
            layout {
                if Config.appleSignInEnabled {
                    Button { go(.apple) } label: {
                        HStack(spacing: 10) {
                            Icon(name: "apple", size: 17, color: Palette.ink)
                            Text(pending == .apple ? "Waiting for browser…" : "Continue with Apple")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: height, fullWidth: true))
                }
                Button { go(.google) } label: {
                    HStack(spacing: 10) {
                        Icon(name: "google", size: 16)
                        Text(pending == .google ? "Waiting for browser…" : "Continue with Google").font(14)
                    }
                }
                .buttonStyle(Config.appleSignInEnabled ? AnyButtonStyle(OutlineButtonStyle(height: height, fullWidth: true))
                                                       : AnyButtonStyle(PrimaryButtonStyle(height: height, fullWidth: true)))
            }
            .disabled(store.signingIn)
            if store.signingIn {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Finish signing in in your browser.").font(12).foregroundColor(Tok.muted)
                    Spacer()
                    Button("Cancel") { store.cancelSignIn(); pending = nil }.buttonStyle(.plain).font(12).underline()
                }
            } else if let err = store.authError {
                Text(err).font(12).foregroundColor(Tok.text).fixedSize(horizontal: false, vertical: true)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
            }
        }
    }

    private func go(_ p: AuthProvider) {
        pending = p
        Task {
            let ok = await store.signIn(p)
            pending = nil
            if ok {
                NSApp.activate(ignoringOtherApps: true)
                onSignedIn()
            }
        }
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ s: S) { make = { AnyView(s.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

// 3d
struct GuestConfirmStep: View {
    @ObservedObject var model: OnboardingModel
    private let rows: [(String, String, String, String)] = [
        ("hard-drive", "Saved on this\nMac only", "cloud", "Backed up\nautomatically"),
        ("trash-2", "Gone if you\ndelete the app", "archive-restore", "Restored\non reinstall"),
        ("monitor-off", "No sync\nbetween Macs", "laptop", "Synced across\nyour Macs"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer().frame(height: 28)
            StepLabel(text: "STEP 2 OF 4 · GUEST")
            VStack(alignment: .leading, spacing: 12) {
                Text("Guest links live on this Mac only.").heading(36).foregroundColor(Tok.text).fixedSize(horizontal: false, vertical: true)
                Text("If you delete Stashbar, your links go with it. A fresh download starts empty.")
                    .font(14).foregroundColor(Tok.muted).fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Guest").font(13).foregroundColor(Tok.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 14)
                    Rectangle().fill(Tok.line).frame(width: 1)
                    HStack(spacing: 6) { Text("Signed in").font(13, .medium); Icon(name: "sparkles", size: 13) }
                        .foregroundColor(Tok.text).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 14)
                }
                ForEach(0..<rows.count, id: \.self) { i in
                    let r = rows[i]
                    Rectangle().fill(Tok.line).frame(height: 1)
                    HStack(spacing: 0) {
                        HStack(spacing: 10) { Icon(name: r.0, size: 15).opacity(0.55); Text(r.1).font(13).foregroundColor(Tok.muted) }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 12)
                        Rectangle().fill(Tok.line).frame(width: 1)
                        HStack(spacing: 10) { Icon(name: r.2, size: 15); Text(r.3).font(13).foregroundColor(Tok.text) }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Tok.line, lineWidth: 1))
            Spacer()
            HStack(spacing: 10) {
                Button("Stay a guest") {
                    Prefs.shared.guestChosen = true
                    model.step = .shortcut
                }
                .buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true))
                Button("Sign in instead") { model.step = .signIn }
                    .buttonStyle(PrimaryButtonStyle(height: 46, fullWidth: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 40).padding(.bottom, 36).padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tok.bg)
    }
}

// 3g
struct RestoreStep: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var store = Store.shared

    var body: some View {
        let total = store.active.count
        VStack(alignment: .leading, spacing: 22) {
            Spacer().frame(height: 28)
            Avatar(account: store.account, size: 56)
            VStack(alignment: .leading, spacing: 10) {
                Text("Welcome back, \(store.account?.firstName ?? "there").").heading(36).foregroundColor(Tok.text)
                Text(store.syncStatus == .syncing ? "Bringing your stash back from your account." : "Your stash is back on this Mac.")
                    .font(14).foregroundColor(Tok.muted)
            }
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Radius.small).fill(Tok.surface)
                        RoundedRectangle(cornerRadius: Radius.small).fill(Palette.accent)
                            .frame(width: store.syncStatus == .syncing ? g.size.width * 0.6 : g.size.width)
                    }
                }
                .frame(height: 8)
                HStack {
                    Text("\(total) link\(total == 1 ? "" : "s") · \(store.tags.count) tag\(store.tags.count == 1 ? "" : "s")")
                    Spacer()
                    Text(store.syncStatus == .syncing ? "Restoring…" : "Done")
                }
                .font(12).foregroundColor(Tok.muted)
            }
            VStack(spacing: 0) {
                ForEach(store.active.prefix(4)) { l in
                    HStack(spacing: 12) {
                        LogoTile(domain: l.domain, size: 30, iconSize: 14)
                        Text(l.title).font(13).foregroundColor(Tok.text).lineLimit(1)
                        Spacer()
                        Icon(name: "check", size: 14).opacity(0.55)
                    }
                    .padding(.vertical, 9)
                    .overlay(alignment: .top) { Rectangle().fill(Tok.line).frame(height: 1) }
                }
            }
            Spacer()
            HStack {
                if let a = store.account {
                    Icon(name: a.provider == .apple ? "apple" : "google", size: 13, color: Tok.muted)
                    Text(a.email).font(13).foregroundColor(Tok.muted).lineLimit(1)
                }
                Spacer()
                Button { model.step = .shortcut } label: {
                    HStack(spacing: 8) { Text("Continue"); Icon(name: "arrow-right", size: 16, color: Palette.ink) }
                }
                .buttonStyle(PrimaryButtonStyle(height: 44))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 40).padding(.bottom, 36).padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tok.bg)
    }
}

// 3e
struct ShortcutStep: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var prefs = Prefs.shared
    @State private var launch = Prefs.shared.launchAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 20)
            StepLabel(text: "STEP 3 OF 4")
            Text("One shortcut to remember.").heading(36).foregroundColor(Tok.text)
            HStack(spacing: 12) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, k in
                    Group {
                        if let icon = k.1 { Icon(name: icon, size: 26, color: Palette.ink) } else { Text(k.0).font(22, .medium).foregroundColor(Palette.ink) }
                    }
                    .frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Palette.line, lineWidth: 1))
                    .shadow(color: Palette.sand, radius: 0, y: 3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Opens Stashbar").font(13).foregroundColor(Tok.text)
                    Text("from any app").font(13).foregroundColor(Tok.muted)
                }
                .padding(.leading, 8)
                Spacer()
                Menu {
                    ForEach(HotKeys.options, id: \.self) { o in Button(o) { prefs.openShortcut = o } }
                } label: { Text("Change").font(13).underline() }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Tok.surface))

            VStack(spacing: 0) {
                permRow("clipboard", "Watch clipboard for links", "Checked locally. Text never leaves your Mac.", $prefs.watchClipboard)
                permRow("shield-check", "Strip tracking parameters", "utm_, fbclid, si and 40 more", $prefs.stripTrackers)
                permRow("power", "Launch at login", "Always ready in the menu bar",
                        Binding(get: { launch }, set: { launch = $0; prefs.launchAtLogin = $0 }))
            }
            Spacer()
            HStack {
                StepDots(index: 2, dark: false)
                Spacer()
                Button { model.step = .done } label: {
                    HStack(spacing: 8) { Text("Continue"); Icon(name: "arrow-right", size: 16, color: Palette.ink) }
                }
                .buttonStyle(PrimaryButtonStyle(height: 44))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 40).padding(.bottom, 28).padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tok.bg)
        .onAppear { if !prefs.onboarded && !model.replay { launch = true; prefs.launchAtLogin = true } }
    }

    private var keys: [(String, String?)] {
        prefs.openShortcut.map { ch -> (String, String?) in
            switch ch {
            case "⌥": return ("⌥", "option")
            case "⌘": return ("⌘", "command")
            default: return (String(ch), nil)
            }
        }
    }

    private func permRow(_ icon: String, _ label: String, _ hint: String, _ on: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Icon(name: icon, size: 17)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(13).foregroundColor(Tok.text)
                Text(hint).font(13).foregroundColor(Tok.muted)
            }
            Spacer()
            PillToggle(isOn: on)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(Tok.line).frame(height: 1) }
    }
}

// 3f
struct DoneStep: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var prefs = Prefs.shared
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Icon(name: "arrow-up", size: 20)
                    Text("Stashbar lives here").font(12).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: Radius.small).fill(Palette.charcoal))
                }
            }
            .padding(.top, 40)
            Spacer().frame(height: 30)
            StepLabel(text: "STEP 4 OF 4")
            Text("You’re set. Copy a link to try it.").heading(44).foregroundColor(Tok.text).fixedSize(horizontal: false, vertical: true)
            Button {
                ClipboardWatcher.shared.writeIgnoringChange("https://stashbar.vercel.app/welcome?utm_source=onboarding")
                Store.shared.clipboardChanged("https://stashbar.vercel.app/welcome?utm_source=onboarding")
                copied = true
            } label: {
                HStack(spacing: 12) {
                    Icon(name: "link", size: 15, color: Palette.ink)
                    Text("stashbar.vercel.app/welcome").font(13).foregroundColor(Palette.ink)
                    Spacer()
                    HStack(spacing: 4) {
                        Icon(name: copied ? "check" : "copy", size: 13, color: Palette.ink)
                        Text(copied ? "Copied" : "Copy").font(12).foregroundColor(Palette.ink)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Palette.accent))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            HStack {
                Text("Then press").font(13).foregroundColor(Tok.muted)
                Spacer()
                Button {
                    prefs.onboarded = true
                    Windows.shared.closeOnboarding()
                    (NSApp.delegate as? AppDelegate)?.togglePopover(forceOpen: true)
                } label: {
                    HStack(spacing: 6) {
                        Text("Open Stashbar")
                        Text(prefs.openShortcut).font(13).padding(.leading, 6)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(height: 44))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 40).padding(.bottom, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tok.surface)
    }
}
