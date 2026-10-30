import Foundation

/// When to post a notification about memory pressure (S-017).
/// One alert when pressure rises into an alerting level, then quiet for
/// 30 minutes, unless pressure climbs higher than the last alert.
public struct PressureAlertRules: Sendable, Equatable {
    public static let quiet: TimeInterval = 30 * 60

    public var whenCritical = true
    public var whenHigh = false

    public private(set) var level: PressureLevel = .normal
    public private(set) var lastAlert: (level: PressureLevel, date: Date)?

    public init() {}

    /// Feed every reading. Returns the level to alert about, or nil.
    public mutating func reading(_ new: PressureLevel, at now: Date) -> PressureLevel? {
        let old = level
        level = new
        guard rank(new) > rank(old), alerts(new) else { return nil }
        if let lastAlert, now.timeIntervalSince(lastAlert.date) < Self.quiet, rank(new) <= rank(lastAlert.level) {
            return nil
        }
        lastAlert = (new, now)
        return new
    }

    private func alerts(_ level: PressureLevel) -> Bool {
        switch level {
        case .normal: false
        case .high: whenHigh
        case .critical: whenCritical
        }
    }

    private func rank(_ level: PressureLevel) -> Int {
        switch level {
        case .normal: 0
        case .high: 1
        case .critical: 2
        }
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.whenCritical == b.whenCritical && a.whenHigh == b.whenHigh && a.level == b.level
            && a.lastAlert?.level == b.lastAlert?.level && a.lastAlert?.date == b.lastAlert?.date
    }
}

/// The notification's words (S-017).
public enum PressureAlertText {
    /// "Memory pressure is Critical"
    public static func title(_ level: PressureLevel) -> String {
        "Memory pressure is \(level.title)"
    }

    /// "Safari uses the most memory: 6.1 GB."
    public static func body(top: AppUsage?) -> String {
        guard let top else { return "Open MangoCleaner to see what uses memory." }
        return "\(top.name) uses the most memory: \(ByteText.string(top.bytes))."
    }
}
