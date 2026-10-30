import AppKit

/// MangoCleaner's own menu bar item. Clicking it is the one way to open and
/// close the memory window, for people, the global shortcut, and snapshots.
enum MenuBarItem {
    static var button: NSStatusBarButton? {
        NSApp.windows
            .filter { $0.className.contains("StatusBar") }
            .compactMap { $0.contentView.flatMap(statusButton(in:)) }
            .first
    }

    /// Opens the memory window, or closes it when it is open.
    static func toggle() {
        NSApp.activate()
        button?.performClick(nil)
    }

    private static func statusButton(in view: NSView) -> NSStatusBarButton? {
        if let button = view as? NSStatusBarButton { return button }
        return view.subviews.lazy.compactMap(statusButton(in:)).first
    }
}
