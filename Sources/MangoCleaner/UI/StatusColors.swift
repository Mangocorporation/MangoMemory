import SwiftUI

/// Status colors: what memory is doing, never the brand. System colors, so
/// they adapt to light, dark, and Increase Contrast on their own.
/// Never show a level by color alone: pair it with its word or symbol.
enum StatusColor {
    /// Memory pressure levels (docs/GLOSSARY.md: Normal / High / Critical).
    static let normal = Color.green
    static let high = Color.yellow
    static let critical = Color.red

    /// The memory breakdown: bar segments and the dots in the details rows.
    static let appMemory = Color.blue
    static let wired = Color.orange
    static let compressed = Color.purple
    static let fileCache = Color.teal
    static let free = Color.secondary.opacity(0.35)
    static let swap = Color.pink
}
