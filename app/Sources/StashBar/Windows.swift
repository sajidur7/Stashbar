import AppKit
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case account, general, onboarding, shortcuts, cleaning, appearance, data, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: return "Account"
        case .general: return "General"
        case .onboarding: return "Onboarding & tips"
        case .shortcuts: return "Shortcuts"
        case .cleaning: return "Link cleaning"
        case .appearance: return "Appearance"
        case .data: return "Data & privacy"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .account: return "circle-user-round"
        case .general: return "settings-2"
        case .onboarding: return "graduation-cap"
        case .shortcuts: return "keyboard"
        case .cleaning: return "shield-check"
        case .appearance: return "palette"
        case .data: return "database"
        case .about: return "info"
        }
    }

    var subtitle: String {
        switch self {
        case .account: return "Your profile, sync and sign-out"
        case .general: return "How Stashbar starts and behaves"
        case .onboarding: return "Welcome tour, hints and first-run preferences"
        case .shortcuts: return "Keys that work from anywhere"
        case .cleaning: return "What gets stripped before a link is saved"
        case .appearance: return "Theme, density and the menu-bar icon"
        case .data: return "Import, export and what leaves your Mac"
        case .about: return "Version, updates and help"
        }
    }
}

enum BackTarget { case links, popover, link(String) }

/// Shared navigation state for the canvas window.
@MainActor
final class CanvasNav: ObservableObject {
    @Published var view: CanvasView = .all
    @Published var query = ""
    @Published var detailID: String?
    @Published var addingLink = false
    @Published var addPrefill = ""
    @Published var confirmDeleteID: String?
}

@MainActor
final class SettingsNav: ObservableObject {
    @Published var section: SettingsSection = .account
    @Published var back: BackTarget = .links
    @Published var dialog: AccountDialog?
}

enum AccountDialog: Equatable {
    case signOutConfirm, signedOut, deleteConfirm, deleted, photo
}

@MainActor
final class Windows: NSObject, NSWindowDelegate {
    static let shared = Windows()

    let canvasNav = CanvasNav()
    let settingsNav = SettingsNav()
    let onboarding = OnboardingModel()

    private var canvasWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    private func makeWindow<V: View>(_ view: V, size: NSSize, min: NSSize, title: String, autosave: String) -> NSWindow {
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.title = title
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.minSize = min
        w.contentView = NSHostingView(rootView: view)
        w.delegate = self
        w.center()
        w.setFrameAutosaveName(autosave)
        return w
    }

    /// One Stashbar surface at a time: showing a window hides the popover and every other
    /// Stashbar window, and the new window takes the place of the one it replaces.
    private func present(_ w: NSWindow) {
        let previous = [canvasWindow, settingsWindow, onboardingWindow]
            .compactMap { $0 }
            .first { $0 !== w && $0.isVisible }
        if let previous, !w.isVisible { placeCentered(w, over: previous) }
        hideAll(except: w)
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    /// Hides the popover and all Stashbar windows except `keep`. State is kept, so going back restores them.
    func hideAll(except keep: NSWindow? = nil) {
        (NSApp.delegate as? AppDelegate)?.closePopover()
        for w in [canvasWindow, settingsWindow, onboardingWindow].compactMap({ $0 }) where w !== keep {
            w.orderOut(nil)
        }
    }

    private func placeCentered(_ w: NSWindow, over old: NSWindow) {
        let c = NSPoint(x: old.frame.midX, y: old.frame.midY)
        var f = w.frame
        f.origin = NSPoint(x: c.x - f.width / 2, y: c.y - f.height / 2)
        if let vis = (old.screen ?? NSScreen.main)?.visibleFrame {
            f.origin.x = min(max(f.origin.x, vis.minX), vis.maxX - f.width)
            f.origin.y = min(max(f.origin.y, vis.minY), vis.maxY - f.height)
        }
        w.setFrame(f, display: false)
    }

    func showCanvas(detail: String? = nil, addLink: Bool = false, view: CanvasView? = nil) {
        if canvasWindow == nil {
            canvasWindow = makeWindow(CanvasRoot(nav: canvasNav), size: NSSize(width: 1100, height: 700),
                                      min: NSSize(width: 820, height: 520), title: "Stashbar", autosave: "StashbarCanvas")
        }
        if let view { canvasNav.view = view; canvasNav.detailID = nil }
        if let detail { canvasNav.detailID = detail }
        if addLink { canvasNav.addPrefill = ""; canvasNav.addingLink = true }
        present(canvasWindow!)
    }

    func showSettings(section: SettingsSection? = nil, from: BackTarget = .links) {
        if settingsWindow == nil {
            settingsWindow = makeWindow(SettingsRoot(nav: settingsNav), size: NSSize(width: 1000, height: 720),
                                        min: NSSize(width: 860, height: 560), title: "Stashbar Settings", autosave: "StashbarSettings")
        }
        if let section { settingsNav.section = section }
        settingsNav.back = from
        present(settingsWindow!)
    }

    func closeSettingsAndGoBack() {
        switch settingsNav.back {
        case .popover: settingsWindow?.orderOut(nil)
        default: break // showCanvas below hides Settings and puts the canvas where it was
        }
        switch settingsNav.back {
        case .links: showCanvas()
        case .link(let id): showCanvas(detail: id)
        case .popover: (NSApp.delegate as? AppDelegate)?.togglePopover(forceOpen: true)
        }
    }

    func showOnboarding(replay: Bool = false) {
        onboarding.reset(replay: replay)
        if onboardingWindow == nil {
            let w = makeWindow(OnboardingRoot(model: onboarding), size: NSSize(width: 480, height: 620),
                               min: NSSize(width: 480, height: 620), title: "Welcome to Stashbar", autosave: "")
            w.styleMask.remove(.resizable)
            onboardingWindow = w
        }
        onboardingWindow?.center()
        present(onboardingWindow!)
    }

    func closeOnboarding() {
        onboardingWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow else { return }
        if w === onboardingWindow, !Prefs.shared.onboarded {
            // Closing the tour early still leaves a working app (guest by default).
            Prefs.shared.onboarded = true
        }
    }
}
