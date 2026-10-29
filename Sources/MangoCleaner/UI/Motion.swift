import AppKit
import SwiftUI

/// Every animation in the app. Under Reduce Motion, movement becomes a short fade
/// or nothing. Never animate a view's first layout, and never animate units:
/// numbers roll with `.contentTransition(.numericText())`.
enum Motion {
    static var reduce: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Hover fills on rows and buttons.
    static var hover: Animation { .easeOut(duration: 0.12) }
    /// Presses and small flips (Quit becomes Force Quit).
    static var quick: Animation { .easeOut(duration: 0.15) }
    /// Ordinary state changes in the window.
    static var ui: Animation { reduce ? .linear(duration: 0.1) : .snappy(duration: 0.25) }
    /// A live number changing (free GB, pressure %).
    static var numberRoll: Animation { reduce ? .linear(duration: 0) : .easeInOut(duration: 0.3) }
    /// Top apps reordering, rows leaving after Quit.
    static var listChange: Animation { reduce ? .linear(duration: 0.1) : .snappy(duration: 0.3) }
    /// The bar segments resizing on refresh.
    static var bar: Animation { reduce ? .linear(duration: 0) : .easeInOut(duration: 0.4) }
}
