import AppKit
import Combine
import SwiftUI

@main
enum StashBarMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let popoverUI = PopoverUI()
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Only one StashBar at a time.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != NSRunningApplication.current }
        if !others.isEmpty {
            others.first?.activate()
            NSApp.terminate(nil)
            return
        }

        Fonts.register()
        let prefs = Prefs.shared
        prefs.applyDock()
        prefs.applyTheme()
        buildMainMenu()
        setupStatusItem()
        setupPopover()

        HotKeys.shared.onOpen = { [weak self] in self?.togglePopover(forceOpen: true) }
        HotKeys.shared.onQuickStash = { [weak self] in self?.quickStash() }
        HotKeys.shared.reload()

        ClipboardWatcher.shared.start()

        Store.shared.$links.combineLatest(prefs.$menuIcon)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.updateStatusTitle() }
            .store(in: &cancellables)

        syncTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { _ in
            Task { @MainActor in if Prefs.shared.autoSync { await Store.shared.syncNow() } }
        }

        if !prefs.onboarded {
            Windows.shared.showOnboarding()
        } else {
            Task { await Store.shared.syncNow() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { Windows.shared.showCanvas() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        let img = IconCache.image("pin-mark-ink")?.copy() as? NSImage
        img?.size = NSSize(width: 18, height: 18)
        img?.isTemplate = true
        button.image = img
        button.imagePosition = .imageLeading
        button.toolTip = "Stashbar — click to open, right-click for options"
        button.target = self
        button.action = #selector(statusClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("Stashbar")
        updateStatusTitle()
    }

    @objc private func statusClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showStatusMenu()
        } else {
            togglePopover()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.delegate = self
        let open = NSMenuItem(title: "Open Stashbar", action: #selector(openPopoverFromMenu), keyEquivalent: "")
        menu.addItem(open)
        menu.addItem(NSMenuItem(title: "Open canvas", action: #selector(openCanvas), keyEquivalent: "e"))
        let stash = NSMenuItem(title: "Stash clipboard", action: #selector(menuQuickStash), keyEquivalent: "")
        stash.isEnabled = Store.shared.clipboardLink != nil
        menu.addItem(stash)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Check for updates…", action: #selector(checkUpdates), keyEquivalent: ""))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Stashbar", action: #selector(quit), keyEquivalent: "q")
        menu.addItem(quit)
        for item in menu.items { item.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // so the next left click opens the popover again
    }

    func menuDidClose(_ menu: NSMenu) { statusItem.menu = nil }

    @objc private func openPopoverFromMenu() { togglePopover(forceOpen: true) }
    @objc private func menuQuickStash() { _ = Store.shared.stashClipboard() }
    @objc func openCanvas() { popover.performClose(nil); Windows.shared.showCanvas() }
    @objc func openSettings() { popover.performClose(nil); Windows.shared.showSettings(from: .popover) }
    @objc private func checkUpdates() { Windows.shared.showSettings(section: .about, from: .popover) }

    /// Fully quits: removes the menu-bar icon and stops every background task (clipboard watcher, sync, hotkeys).
    @objc func quit() {
        NSApp.terminate(nil)
    }

    private func updateStatusTitle() {
        guard let button = statusItem?.button else { return }
        if Prefs.shared.menuIcon == "Pin + count" {
            button.title = " \(Store.shared.active.count)"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        } else {
            button.title = ""
        }
    }

    // MARK: Popover

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let host = NSHostingController(rootView: PopoverView(ui: popoverUI, actions: PopoverActions(
            openCanvas: { [weak self] in self?.openCanvas() },
            openSettings: { [weak self] in self?.openSettings() },
            openDetail: { [weak self] id in self?.popover.performClose(nil); Windows.shared.showCanvas(detail: id) },
            close: { [weak self] in self?.popover.performClose(nil) },
            signIn: { [weak self] in self?.popover.performClose(nil); Windows.shared.showSettings(section: .account, from: .popover) }
        )))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
    }

    func togglePopover(forceOpen: Bool = false) {
        guard let button = statusItem.button else { return }
        if popover.isShown && !forceOpen {
            popover.performClose(nil)
            return
        }
        if !popover.isShown {
            popoverUI.reset()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            popoverUI.focusSearch.toggle()
            Task { await Store.shared.syncNow() }
        }
    }

    private func quickStash() {
        if Store.shared.stashClipboard() {
            flashStatus()
        } else {
            togglePopover(forceOpen: true)
        }
    }

    private func flashStatus() {
        guard let button = statusItem.button else { return }
        let old = button.title
        button.title = " Stashed"
        button.font = Fonts.nsFont(12, .medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            button.title = old
            self?.updateStatusTitle()
        }
    }

    // MARK: Main menu (gives text fields ⌘C / ⌘V / ⌘A and windows ⌘W)

    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Stashbar", action: #selector(openAbout), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide Stashbar", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Quit Stashbar", action: #selector(quit), keyEquivalent: "q"))
        for i in appMenu.items where i.action == #selector(openSettings) || i.action == #selector(quit) || i.action == #selector(openAbout) {
            i.target = self
        }
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let add = NSMenuItem(title: "Add link…", action: #selector(addLink), keyEquivalent: "n")
        add.target = self
        fileMenu.addItem(add)
        let canvas = NSMenuItem(title: "Open canvas", action: #selector(openCanvas), keyEquivalent: "e")
        canvas.target = self
        fileMenu.addItem(canvas)
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(title: "Close window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = edit
        main.addItem(editItem)

        let winItem = NSMenuItem()
        let win = NSMenu(title: "Window")
        win.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        winItem.submenu = win
        main.addItem(winItem)
        NSApp.mainMenu = main
        NSApp.windowsMenu = win
    }

    @objc private func openAbout() { Windows.shared.showSettings(section: .about, from: .links) }
    @objc private func addLink() { Windows.shared.showCanvas(addLink: true) }
}

// MARK: - Popover UI state

@MainActor
final class PopoverUI: ObservableObject {
    @Published var query = ""
    @Published var adding = false
    @Published var focusSearch = false

    func reset() {
        query = ""
        adding = false
        Store.shared.clipboardNotALink = false
    }
}

struct PopoverActions {
    var openCanvas: () -> Void
    var openSettings: () -> Void
    var openDetail: (String) -> Void
    var close: () -> Void
    var signIn: () -> Void
}
