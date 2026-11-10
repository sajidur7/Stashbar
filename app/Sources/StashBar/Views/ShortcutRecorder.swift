import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Lets the user pick a preset or record any custom global shortcut.
/// While recording, the current hotkeys are suspended so pressing them is captured too.
@MainActor
final class ShortcutRecording: ObservableObject {
    @Published var isRecording = false
    @Published var message: String?
    private var monitor: Any?

    func start() {
        message = nil
        isRecording = true
        HotKeys.shared.suspend()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return nil // swallow keys while recording
        }
    }

    func cancel() {
        stop()
        HotKeys.shared.reload()
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if Int(event.keyCode) == kVK_Escape && flags.subtracting(.capsLock).isEmpty {
            cancel()
            return
        }
        let mods = HotKeys.carbonMods(flags)
        // Needs ⌘, ⌥ or ⌃ so normal typing isn't hijacked.
        let strong = UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey)
        guard mods & strong != 0 else {
            message = "Add ⌘, ⌥ or ⌃ — e.g. ⌥S or ⌃⇧K."
            return
        }
        let label = HotKeys.label(mods: mods, key: HotKeys.keyName(event))
        stop()
        Prefs.shared.openKeyCode = Int(event.keyCode)
        Prefs.shared.openShortcut = label // re-registers the hotkeys
        message = nil
    }
}

struct ShortcutPicker<Label: View>: View {
    @ObservedObject var recording: ShortcutRecording
    @ViewBuilder var label: () -> Label

    var body: some View {
        Menu {
            ForEach(HotKeys.options, id: \.self) { o in
                Button(o) { HotKeys.applyPreset(o) }
            }
            Divider()
            Button("Record custom shortcut…") { recording.start() }
        } label: { label() }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// Shown while recording: "Press keys…" keycap with a cancel button and any hint.
struct RecordingCap: View {
    @ObservedObject var recording: ShortcutRecording
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 8) {
                Text("Press new shortcut…").font(13, .medium).foregroundColor(Palette.ink)
                    .padding(.horizontal, 12).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: Radius.control).fill(Palette.accent))
                Button("Cancel") { recording.cancel() }
                    .buttonStyle(.plain).font(12).foregroundColor(Tok.muted).underline()
            }
            if let m = recording.message {
                Text(m).font(12).foregroundColor(Tok.muted)
            }
        }
    }
}
