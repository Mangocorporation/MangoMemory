import SwiftUI

/// Corner radii. Inner corners are concentric: inner = outer - inset.
enum Radius {
    /// Chips, key caps, the stacked memory bar.
    static let xs: CGFloat = 6
    /// Controls.
    static let sm: CGFloat = 8
    /// Row hover and selection fills (top apps).
    static let row: CGFloat = 10
    /// Cards inside the memory window.
    static let md: CGFloat = 12
}
