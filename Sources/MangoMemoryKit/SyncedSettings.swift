import Foundation

/// Every setting that syncs through iCloud Drive, as one small JSON file.
/// The newest change wins as a whole: settings are few and change rarely.
public struct SyncedSettings: Codable, Equatable, Sendable {
    public struct Values: Codable, Equatable, Sendable {
        public var refreshInterval: Int
        public var menuBarText: String
        public var largeMenuBarText: Bool
        public var openAtLogin: Bool
        public var shortcut: Shortcut?
        public var clearWhenPressureHigh: Bool
        public var highFor: TimeInterval
        public var clearAfterBigQuit: Bool
        public var bigApp: UInt64
        public var notifyCritical: Bool
        public var notifyHigh: Bool
        public var accent: String

        public init(refreshInterval: Int, menuBarText: String, largeMenuBarText: Bool, openAtLogin: Bool,
                    shortcut: Shortcut?, clearWhenPressureHigh: Bool, highFor: TimeInterval,
                    clearAfterBigQuit: Bool, bigApp: UInt64, notifyCritical: Bool, notifyHigh: Bool,
                    accent: String) {
            self.refreshInterval = refreshInterval
            self.menuBarText = menuBarText
            self.largeMenuBarText = largeMenuBarText
            self.openAtLogin = openAtLogin
            self.shortcut = shortcut
            self.clearWhenPressureHigh = clearWhenPressureHigh
            self.highFor = highFor
            self.clearAfterBigQuit = clearAfterBigQuit
            self.bigApp = bigApp
            self.notifyCritical = notifyCritical
            self.notifyHigh = notifyHigh
            self.accent = accent
        }
    }

    public var values: Values
    /// When these values were changed, and on which Mac.
    public var modified: Date
    public var device: String

    public init(values: Values, modified: Date, device: String) {
        self.values = values
        self.modified = modified
        self.device = device
    }

    /// True when this file should replace what this Mac has: it is newer and differs.
    public func replaces(_ local: Values, changedAt localModified: Date?) -> Bool {
        values != local && modified > (localModified ?? .distantPast)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> SyncedSettings {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncedSettings.self, from: data)
    }
}
