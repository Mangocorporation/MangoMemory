import Foundation

/// A key with modifiers that opens the memory window from any app (S-018).
public struct Shortcut: Codable, Equatable, Sendable {
    public struct Modifiers: OptionSet, Codable, Equatable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1)
        public static let option = Modifiers(rawValue: 2)
        public static let shift = Modifiers(rawValue: 4)
        public static let command = Modifiers(rawValue: 8)
    }

    /// The virtual key code (kVK_ANSI_M is 46).
    public var keyCode: UInt16
    public var modifiers: Modifiers
    /// What the key types, for display: "M".
    public var key: String

    public init(keyCode: UInt16, modifiers: Modifiers, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// Control-Option-M.
    public static let standard = Shortcut(keyCode: 46, modifiers: [.control, .option], key: "M")

    /// A global shortcut needs Control, Option, or Command, so plain typing never triggers it.
    public var isValid: Bool {
        !modifiers.isDisjoint(with: [.control, .option, .command]) && !key.isEmpty
    }

    /// "⌃⌥M", in Apple's modifier order.
    public var display: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + key.uppercased()
    }

    /// Carbon's modifier bits for RegisterEventHotKey.
    public var carbonModifiers: UInt32 {
        var bits: UInt32 = 0
        if modifiers.contains(.command) { bits |= 0x0100 }
        if modifiers.contains(.shift) { bits |= 0x0200 }
        if modifiers.contains(.option) { bits |= 0x0800 }
        if modifiers.contains(.control) { bits |= 0x1000 }
        return bits
    }
}
