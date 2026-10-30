import Foundation

/// What started a Clear File Cache.
public enum CleanTrigger: String, Sendable {
    case button, menu, pressure, afterQuit
}

/// The before and after of one Clear File Cache (S-012).
public struct CleanResult: Sendable, Equatable {
    public var date: Date
    public var trigger: CleanTrigger
    public var availableBefore: UInt64
    public var availableAfter: UInt64
    public var pressureBefore: Int
    public var pressureAfter: Int

    /// Below this, the result says honestly that there was little to clear.
    public static let noticeable: UInt64 = 50 * 1_048_576

    public init(date: Date, trigger: CleanTrigger, before: MemoryStats, after: MemoryStats) {
        self.date = date
        self.trigger = trigger
        availableBefore = before.available
        availableAfter = after.available
        pressureBefore = before.pressurePercent
        pressureAfter = after.pressurePercent
    }

    /// Never negative: memory other apps took meanwhile is not our loss.
    public var freed: UInt64 {
        availableAfter > availableBefore ? availableAfter - availableBefore : 0
    }

    /// "Freed 1.2 GB · pressure 62 % → 48 %", or "Nothing much to clear".
    public var summary: String {
        guard freed >= Self.noticeable else { return "Nothing much to clear" }
        return "Freed \(ByteText.string(freed)) · pressure \(pressureBefore) % → \(pressureAfter) %"
    }
}

/// The helper's XPC interface. The app and MangoMemoryHelper both compile this.
@objc public protocol HelperProtocol {
    /// Runs /usr/sbin/purge and replies with its exit code. Takes no arguments
    /// from the caller on purpose: the helper can do this one thing only.
    func clearFileCache(reply: @escaping @Sendable (Int32) -> Void)
}

public enum Helper {
    public static let machService = "com.mangocorp.mangomemory.helper"
    public static let plistName = "com.mangocorp.mangomemory.helper.plist"
    /// Only MangoMemory signed by this team may call the helper.
    public static let clientRequirement =
        #"identifier "com.mangocorp.mangomemory" and anchor apple generic and certificate leaf[subject.OU] = "SJR7785KA2""#
}
