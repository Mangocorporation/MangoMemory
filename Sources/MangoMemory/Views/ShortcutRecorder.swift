import AppKit
import Carbon.HIToolbox
import MangoMemoryKit
import SwiftUI

/// Click, then type a shortcut. Escape cancels, Delete removes it (S-018).
struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut?
    /// True while recording, so the global shortcut does not fire instead.
    var onRecording: (Bool) -> Void = { _ in }
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: Space.sm) {
            Button(recording ? "Type Shortcut" : shortcut?.display ?? "Record Shortcut") {
                recording ? stop() : start()
            }
            .help(recording ? "Type a key with ⌃, ⌥, or ⌘. Escape cancels." : "Click to record a new shortcut")
            if shortcut != nil, !recording {
                Button("Remove Shortcut", systemImage: "xmark.circle.fill") { shortcut = nil }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove the shortcut")
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        onRecording(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                stop()
            case kVK_Delete, kVK_ForwardDelete:
                shortcut = nil
                stop()
            default:
                let typed = Shortcut(keyCode: event.keyCode, modifiers: Self.modifiers(event.modifierFlags),
                                     key: event.charactersIgnoringModifiers ?? "")
                if typed.isValid {
                    shortcut = typed
                    stop()
                } else {
                    NSSound.beep()
                }
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { onRecording(false) }
        recording = false
    }

    private static func modifiers(_ flags: NSEvent.ModifierFlags) -> Shortcut.Modifiers {
        var result: Shortcut.Modifiers = []
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        return result
    }
}
