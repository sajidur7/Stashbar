import AppKit
import ServiceManagement
import SwiftUI

/// User preferences (stored per Mac in UserDefaults).
final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    @Published var onboarded: Bool { didSet { d.set(onboarded, forKey: "onboarded") } }
    @Published var guestChosen: Bool { didSet { d.set(guestChosen, forKey: "guestChosen") } }

    // General
    @Published var showInDock: Bool { didSet { d.set(showInDock, forKey: "showInDock"); applyDock() } }
    @Published var watchClipboard: Bool { didSet { d.set(watchClipboard, forKey: "watchClipboard") } }
    @Published var playSound: Bool { didSet { d.set(playSound, forKey: "playSound") } }
    @Published var popoverCount: String { didSet { d.set(popoverCount, forKey: "popoverCount") } }

    // Onboarding & tips
    @Published var tourOnNewMacs: Bool { didSet { d.set(tourOnNewMacs, forKey: "tourOnNewMacs") } }
    @Published var inlineTips: Bool { didSet { d.set(inlineTips, forKey: "inlineTips") } }
    @Published var dismissedTips: [String] { didSet { d.set(dismissedTips, forKey: "dismissedTips") } }

    // Shortcuts
    @Published var openShortcut: String { didSet { d.set(openShortcut, forKey: "openShortcut"); HotKeys.shared.reload() } }

    // Cleaning
    @Published var stripTrackers: Bool { didSet { d.set(stripTrackers, forKey: "stripTrackers") } }
    @Published var copyClean: Bool { didSet { d.set(copyClean, forKey: "copyClean") } }
    @Published var expandShortLinks: Bool { didSet { d.set(expandShortLinks, forKey: "expandShortLinks") } }
    @Published var trackerList: [String] { didSet { d.set(trackerList, forKey: "trackerList") } }

    // Appearance
    @Published var theme: String { didSet { d.set(theme, forKey: "theme"); applyTheme() } }
    @Published var density: String { didSet { d.set(density, forKey: "density") } }
    @Published var menuIcon: String { didSet { d.set(menuIcon, forKey: "menuIcon") } }
    @Published var linkPreviews: Bool { didSet { d.set(linkPreviews, forKey: "linkPreviews") } }

    // Sync
    @Published var autoSync: Bool { didSet { d.set(autoSync, forKey: "autoSync") } }

    let deviceID: String

    private init() {
        d.register(defaults: [
            "showInDock": false, "watchClipboard": true, "playSound": true, "popoverCount": "10",
            "tourOnNewMacs": true, "inlineTips": true, "openShortcut": "⌥S",
            "stripTrackers": true, "copyClean": true, "expandShortLinks": true,
            "theme": "System", "density": "Comfortable", "menuIcon": "Pin", "linkPreviews": true, "autoSync": true,
        ])
        onboarded = d.bool(forKey: "onboarded")
        guestChosen = d.bool(forKey: "guestChosen")
        showInDock = d.bool(forKey: "showInDock")
        watchClipboard = d.bool(forKey: "watchClipboard")
        playSound = d.bool(forKey: "playSound")
        popoverCount = d.string(forKey: "popoverCount") ?? "10"
        tourOnNewMacs = d.bool(forKey: "tourOnNewMacs")
        inlineTips = d.bool(forKey: "inlineTips")
        dismissedTips = d.stringArray(forKey: "dismissedTips") ?? []
        openShortcut = d.string(forKey: "openShortcut") ?? "⌥S"
        stripTrackers = d.bool(forKey: "stripTrackers")
        copyClean = d.bool(forKey: "copyClean")
        expandShortLinks = d.bool(forKey: "expandShortLinks")
        trackerList = d.stringArray(forKey: "trackerList") ?? LinkCleaner.defaultTrackers
        theme = d.string(forKey: "theme") ?? "System"
        density = d.string(forKey: "density") ?? "Comfortable"
        menuIcon = d.string(forKey: "menuIcon") ?? "Pin"
        linkPreviews = d.bool(forKey: "linkPreviews")
        autoSync = d.bool(forKey: "autoSync")
        if let id = d.string(forKey: "deviceID") {
            deviceID = id
        } else {
            deviceID = UUID().uuidString.lowercased()
            d.set(deviceID, forKey: "deviceID")
        }
    }

    var popoverLimit: Int { Int(popoverCount) ?? 10 }
    var compact: Bool { density == "Compact" }

    // MARK: Launch at login (SMAppService, macOS 13+)

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("StashBar: launch at login change failed: \(error)")
            }
        }
    }

    func applyDock() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    func applyTheme() {
        switch theme {
        case "Light": NSApp.appearance = NSAppearance(named: .aqua)
        case "Dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }

    func resetTips() { dismissedTips = [] }
}
