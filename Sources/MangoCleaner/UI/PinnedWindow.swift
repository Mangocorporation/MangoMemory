import AppKit
import SwiftUI

/// The memory window pinned outside the menu bar (S-025): it floats above
/// other windows, on every Space, where the drop-down was.
enum PinnedWindow {
    static let id = "memory"

    static var window: NSWindow? {
        NSApp.windows.first { $0.isVisible && $0.identifier?.rawValue.hasPrefix(id) == true }
    }

    /// Sets the window up once it exists.
    struct Hook: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                guard let window = view.window else { return }
                window.level = .floating
                window.collectionBehavior.insert(.canJoinAllSpaces)
                window.isMovableByWindowBackground = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                // Under the menu bar item, like the drop-down.
                if let item = MenuBarItem.button?.window?.frame {
                    let x = min(item.minX, (window.screen?.visibleFrame.maxX ?? item.maxX) - window.frame.width - 8)
                    window.setFrameTopLeftPoint(NSPoint(x: x, y: item.minY - 6))
                }
                NSApp.activate()
                window.makeKeyAndOrderFront(nil)
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {}
    }
}
