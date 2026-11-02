import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct DialogIcon: View {
    let name: String
    var dark = false
    var body: some View {
        Icon(name: name, size: 22, color: dark ? .white : Tok.text)
            .frame(width: 52, height: 52)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(dark ? Palette.charcoal : Tok.bg))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(dark ? Color.clear : Tok.line, lineWidth: 1))
    }
}

// 3w
struct SignOutConfirmDialog: View {
    @ObservedObject var nav: SettingsNav
    @State private var keep = true
    private var store: Store { Store.shared }

    var body: some View {
        DialogCard {
            DialogIcon(name: "log-out")
            VStack(alignment: .leading, spacing: 8) {
                Text("Sign out of Stashbar?").heading(28).foregroundColor(Tok.text)
                Text("Your \(store.links.count) links are safe in your account. Choose what stays on this Mac:")
                    .font(13).foregroundColor(Tok.muted).fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 8) {
                option(true, "Keep a local copy", "Continue as a guest with these links")
                option(false, "Remove from this Mac", "Start empty. Sign in again to restore everything")
            }
            HStack(spacing: 10) {
                Button("Cancel") { nav.dialog = nil }
                    .buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true))
                    .keyboardShortcut(.cancelAction)
                Button("Sign out") {
                    Task {
                        await store.syncNow() // push anything pending first
                        store.signOut(keepLocal: keep)
                        nav.dialog = .signedOut
                    }
                }
                .buttonStyle(DarkButtonStyle(height: 46, fullWidth: true))
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func option(_ value: Bool, _ title: String, _ hint: String) -> some View {
        let on = keep == value
        return Button { keep = value } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().strokeBorder(Tok.text, lineWidth: 1).frame(width: 18, height: 18)
                    if on { Circle().fill(Tok.text).frame(width: 10, height: 10) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(13, .medium).foregroundColor(Tok.text)
                    Text(hint).font(12).foregroundColor(Tok.muted)
                }
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(on ? Tok.surface : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(on ? Tok.text : Tok.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// 3wa
struct SignedOutDialog: View {
    @ObservedObject var nav: SettingsNav
    @ObservedObject private var store = Store.shared

    var body: some View {
        DialogCard {
            DialogIcon(name: "check")
            VStack(alignment: .leading, spacing: 8) {
                Text("You’re signed out.").heading(28).foregroundColor(Tok.text)
                Text(store.links.isEmpty
                     ? "Your links were removed from this Mac. They’re still in your account — sign in again to restore them."
                     : "Your \(store.links.count) links stayed on this Mac. You’re now using Stashbar as a guest.")
                    .font(13).foregroundColor(Tok.muted).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Icon(name: "hard-drive", size: 15)
                Text("Guest mode: links aren’t backed up until you sign in again.").font(13).foregroundColor(Tok.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
            HStack(spacing: 10) {
                Button("Sign in again") { nav.dialog = nil; nav.section = .account }
                    .buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true))
                Button("Done") { nav.dialog = nil }
                    .buttonStyle(PrimaryButtonStyle(height: 46, fullWidth: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

// 3wb
struct DeleteAccountDialog: View {
    @ObservedObject var nav: SettingsNav
    @ObservedObject private var store = Store.shared
    @State private var understood = false
    @State private var working = false
    @State private var error: String?
    @State private var needsReauth = false

    var body: some View {
        DialogCard {
            DialogIcon(name: "trash-2", dark: true)
            VStack(alignment: .leading, spacing: 8) {
                Text("Delete your account?").heading(28).foregroundColor(Tok.text)
                Text("This permanently removes your account and all \(store.links.count) links from every Mac. It can’t be undone.")
                    .font(13).foregroundColor(Tok.muted).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                bullet("Links, tags and notes")
                bullet("Sync on \(max(store.devices.count, 1)) Mac\(store.devices.count == 1 ? "" : "s")")
                bullet("Your \(store.account?.provider.label ?? "Apple / Google") sign-in link")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Tok.surface))
            Button { ImportExport.export(store.links, format: .json) } label: {
                HStack(spacing: 8) { Icon(name: "download", size: 14); Text("Export my links first").underline() }
                    .font(13).foregroundColor(Tok.text)
            }
            .buttonStyle(.plain)
            Button { understood.toggle() } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.small).fill(understood ? Palette.charcoal : Color.clear).frame(width: 20, height: 20)
                        RoundedRectangle(cornerRadius: Radius.small).strokeBorder(Tok.text, lineWidth: 1).frame(width: 20, height: 20)
                        if understood { Icon(name: "check", size: 13, color: .white) }
                    }
                    Text("I understand this is permanent").font(13).foregroundColor(Tok.text)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let error {
                Text(error).font(12).foregroundColor(Tok.text).padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
            }
            HStack(spacing: 10) {
                Button("Cancel") { nav.dialog = nil }
                    .buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true))
                    .keyboardShortcut(.cancelAction)
                    .disabled(working)
                Button { run() } label: {
                    HStack(spacing: 8) {
                        if working { ProgressView().controlSize(.small).colorInvert() }
                        Text(needsReauth ? "Sign in & delete" : "Delete account")
                    }
                }
                .buttonStyle(DarkButtonStyle(height: 46, fullWidth: true))
                .disabled(!understood || working)
                .opacity(!understood ? 0.4 : 1)
            }
        }
    }

    private func bullet(_ s: String) -> some View {
        HStack(spacing: 8) { Icon(name: "x", size: 12); Text(s).font(13).foregroundColor(Tok.text) }
    }

    private func run() {
        working = true
        error = nil
        Task {
            if needsReauth, let p = store.account?.provider {
                let ok = await store.signIn(p)
                if !ok { working = false; error = store.authError ?? "Sign-in didn’t finish."; return }
            }
            do {
                try await store.deleteAccount()
                working = false
                nav.dialog = .deleted
            } catch AuthError.needsRecentLogin {
                working = false
                needsReauth = true
                error = "For your safety, Firebase needs a fresh sign-in before deleting. Press the button again to sign in and finish."
            } catch {
                working = false
                self.error = error.localizedDescription
            }
        }
    }
}

// 3wc
struct AccountDeletedDialog: View {
    @ObservedObject var nav: SettingsNav
    var body: some View {
        DialogCard {
            DialogIcon(name: "check")
            VStack(alignment: .leading, spacing: 8) {
                Text("Account deleted.").heading(28).foregroundColor(Tok.text)
                Text("Everything is gone from our servers. Other Macs signed in to this account will sign out on their next sync. Thanks for trying Stashbar.")
                    .font(13).foregroundColor(Tok.muted).fixedSize(horizontal: false, vertical: true)
            }
            Button("Start over") {
                nav.dialog = nil
                Prefs.shared.onboarded = false
                Windows.shared.showOnboarding()
            }
            .buttonStyle(PrimaryButtonStyle(height: 46, fullWidth: true))
            .keyboardShortcut(.defaultAction)
        }
    }
}

// 3wd
struct ProfilePhotoDialog: View {
    @ObservedObject var nav: SettingsNav
    @ObservedObject private var store = Store.shared
    @State private var photo: Data?
    @State private var style = 0
    @State private var loaded = false

    var body: some View {
        DialogCard {
            HStack(alignment: .top) {
                Text("Profile photo").heading(28).foregroundColor(Tok.text)
                Spacer()
                Button { nav.dialog = nil } label: {
                    Icon(name: "x", size: 14).frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
                }
                .buttonStyle(.plain).keyboardShortcut(.cancelAction)
            }
            HStack { Spacer(); Avatar(account: preview, size: 120); Spacer() }.padding(.vertical, 6)
            Button { pick() } label: {
                HStack(spacing: 8) { Icon(name: "upload", size: 15); Text("Upload a photo") }
            }
            .buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true))
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Or pick a monogram")
                HStack(spacing: 10) {
                    ForEach(MonogramStyle.allCases, id: \.rawValue) { s in
                        Button { style = s.rawValue; photo = nil } label: {
                            Text(store.account?.initials ?? "SB")
                                .font(Fonts.ui(13, .medium))
                                .foregroundColor(s.fg)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(s.bg))
                                .overlay(Circle().strokeBorder(photo == nil && style == s.rawValue ? Palette.ink : s.border,
                                                               lineWidth: photo == nil && style == s.rawValue ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("JPG or PNG, square works best. Shown on every Mac you sign in to.").font(12).foregroundColor(Tok.muted)
            HStack(spacing: 10) {
                Button("Remove photo") { photo = nil }
                    .buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true))
                    .disabled(photo == nil)
                Button("Save") {
                    store.updateProfile(photo: photo, monogramStyle: style)
                    nav.dialog = nil
                    store.celebrate("Profile updated")
                }
                .buttonStyle(PrimaryButtonStyle(height: 46, fullWidth: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            photo = store.account?.photo
            style = store.account?.monogramStyle ?? 0
        }
    }

    private var preview: Account? {
        guard var a = store.account else { return nil }
        a.photo = photo
        a.monogramStyle = style
        return a
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic, .image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) else { return }
        photo = Self.squareJPEG(img, side: 256)
    }

    /// Centre-crops to a square and re-encodes as a small JPEG (fits Firestore's 1 MB document limit).
    static func squareJPEG(_ image: NSImage, side: CGFloat) -> Data? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height), s = min(w, h)
        guard let cropped = cg.cropping(to: CGRect(x: (w - s) / 2, y: (h - s) / 2, width: s, height: s)) else { return nil }
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side), bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)
        guard let rep else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: cropped, size: NSSize(width: s, height: s)).draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
    }
}
