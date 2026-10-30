import Foundation

/// What the menu bar item shows next to its glyph (S-023).
public enum MenuBarText: String, CaseIterable, Sendable {
    case available, pressure, iconOnly

    public var title: String {
        switch self {
        case .available: "Available memory"
        case .pressure: "Pressure %"
        case .iconOnly: "Icon only"
        }
    }

    /// "6.4 GB", "34 %", or nil for the glyph alone.
    public func text(for stats: MemoryStats?) -> String? {
        guard let stats else { return nil }
        switch self {
        case .available: return ByteText.string(stats.available)
        case .pressure: return "\(stats.pressurePercent) %"
        case .iconOnly: return nil
        }
    }
}
