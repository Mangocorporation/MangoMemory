import Foundation

/// When MangoMemory clears the file cache on its own (S-014, S-015).
/// A value type with the clock passed in, so tests never wait.
public struct AutoClearRules: Sendable, Equatable {
    /// After any clear, automatic or not, automatic clears wait this long.
    public static let cooldown: TimeInterval = 180
    public static let durations: [TimeInterval] = [30, 60, 300]
    public static let thresholds: [UInt64] = [1, 2, 4].map { $0 * 1_073_741_824 }

    /// Clear when pressure stays High or Critical for `highFor` seconds.
    public var whenPressureHigh = false
    public var highFor: TimeInterval = 60
    /// Clear when an app that used more than `bigApp` bytes quits.
    public var afterBigQuit = false
    public var bigApp: UInt64 = 2 * 1_073_741_824

    public private(set) var highSince: Date?
    public private(set) var lastClear: Date?
    /// App sizes from the last reading, by pid.
    public private(set) var sizes: [Int32: UInt64] = [:]

    public init() {}

    /// When the cooldown ends, or nil when it is over.
    public func nextPossible(at now: Date) -> Date? {
        guard let lastClear else { return nil }
        let end = lastClear.addingTimeInterval(Self.cooldown)
        return end > now ? end : nil
    }

    /// Feed every pressure reading. True when it is time to clear.
    public mutating func pressure(_ level: PressureLevel, at now: Date) -> Bool {
        guard level != .normal else {
            highSince = nil
            return false
        }
        let since = highSince ?? now
        highSince = since
        guard whenPressureHigh, nextPossible(at: now) == nil else { return false }
        return now.timeIntervalSince(since) >= highFor
    }

    /// Feed the apps' sizes now and then, so a quit can be measured.
    public mutating func appSizes(_ apps: [AppUsage]) {
        sizes = Dictionary(apps.map { ($0.pid, $0.bytes) }, uniquingKeysWith: max)
    }

    /// An app quit. True when it was big enough to clear after.
    public mutating func appQuit(pid: Int32, at now: Date) -> Bool {
        let bytes = sizes.removeValue(forKey: pid) ?? 0
        return afterBigQuit && bytes >= bigApp && nextPossible(at: now) == nil
    }

    /// Any clear starts the cooldown, and pressure must stay high for the full
    /// time again before the next automatic clear.
    public mutating func cleared(at now: Date) {
        lastClear = now
        if highSince != nil { highSince = now }
    }
}

/// The line under the automation toggles (S-016).
public enum AutoClearText {
    /// "Last automatic clear 4 min ago · freed 900 MB. Next possible in 2:10."
    public static func status(last: CleanResult?, nextPossible: Date?, now: Date) -> String? {
        var parts: [String] = []
        if let last {
            let freed = last.freed >= CleanResult.noticeable ? "freed \(ByteText.string(last.freed))" : "nothing much to clear"
            parts.append("Last automatic clear \(ago(last.date, now: now)) · \(freed).")
        }
        if let nextPossible {
            let seconds = max(0, Int(nextPossible.timeIntervalSince(now).rounded(.up)))
            parts.append("Next possible in \(seconds / 60):\(String(format: "%02d", seconds % 60)).")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    static func ago(_ date: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date)) / 60
        switch minutes {
        case ..<1: return "just now"
        case ..<60: return "\(minutes) min ago"
        default: return "\(minutes / 60) h ago"
        }
    }
}
