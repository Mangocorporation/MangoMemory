import Foundation
import Testing
@testable import MangoCleanerKit

private let gb: UInt64 = 1_073_741_824
private let start = Date(timeIntervalSinceReferenceDate: 0)

private func rules(pressure: Bool = true, quit: Bool = false) -> AutoClearRules {
    var rules = AutoClearRules()
    rules.whenPressureHigh = pressure
    rules.highFor = 60
    rules.afterBigQuit = quit
    rules.bigApp = 2 * gb
    return rules
}

@Test("Clears only after pressure stays high for the full time")
func fullDuration() {
    var r = rules()
    do { let fired = r.pressure(.high, at: start); #expect(!fired) }
    do { let fired = r.pressure(.critical, at: start + 59); #expect(!fired) }
    do { let fired = r.pressure(.high, at: start + 60); #expect(fired) }
}

@Test("A Normal reading starts the wait over")
func normalResets() {
    var r = rules()
    _ = r.pressure(.high, at: start)
    _ = r.pressure(.normal, at: start + 40)
    do { let fired = r.pressure(.high, at: start + 61); #expect(!fired) }
    do { let fired = r.pressure(.high, at: start + 120); #expect(!fired) }
    do { let fired = r.pressure(.high, at: start + 121); #expect(fired) }
}

@Test("After a clear, it waits the cooldown and the full time again")
func cooldown() {
    var r = rules()
    _ = r.pressure(.high, at: start)
    do { let fired = r.pressure(.high, at: start + 60); #expect(fired) }
    r.cleared(at: start + 60)
    #expect(r.nextPossible(at: start + 60) == start + 240)
    do { let fired = r.pressure(.high, at: start + 200); #expect(!fired) }
    do { let fired = r.pressure(.high, at: start + 240); #expect(fired) }
}

@Test("A stream of high readings clears once per cooldown")
func oncePerCooldown() {
    var r = rules()
    var clears = 0
    for second in stride(from: 0.0, through: 600, by: 2) where r.pressure(.high, at: start + second) {
        clears += 1
        r.cleared(at: start + second)
    }
    // At 60, 240, 420, 600.
    #expect(clears == 4)
}

@Test("Off means never")
func off() {
    var r = rules(pressure: false)
    _ = r.pressure(.critical, at: start)
    do { let fired = r.pressure(.critical, at: start + 3600); #expect(!fired) }
}

@Test("Clears after an app over the threshold quits, within the shared cooldown")
func bigQuit() {
    var r = rules(pressure: false, quit: true)
    r.appSizes([AppUsage(pid: 1, name: "Big", bundlePath: nil, bytes: 3 * gb),
                AppUsage(pid: 2, name: "Small", bundlePath: nil, bytes: gb)])
    do { let fired = r.appQuit(pid: 2, at: start); #expect(!fired) }
    do { let fired = r.appQuit(pid: 9, at: start); #expect(!fired) }
    do { let fired = r.appQuit(pid: 1, at: start); #expect(fired) }
    r.appSizes([AppUsage(pid: 3, name: "Big", bundlePath: nil, bytes: 5 * gb)])
    r.cleared(at: start)
    do { let fired = r.appQuit(pid: 3, at: start + 100); #expect(!fired) }
}

@Test("The status line says when it last cleared and when it can again")
func statusLine() {
    var after = MemoryStats(total: 24 * gb, app: 0, wired: 0, compressed: 0, fileCache: 0, free: 0,
                            swapUsed: 0, level: .normal, pressurePercent: 40)
    let before = after
    after.free = 943_718_400
    let last = CleanResult(date: start, trigger: .pressure, before: before, after: after)
    #expect(AutoClearText.status(last: last, nextPossible: start + 180, now: start + 50)
            == "Last automatic clear just now · freed 900 MB. Next possible in 2:10.")
    #expect(AutoClearText.status(last: last, nextPossible: nil, now: start + 250)
            == "Last automatic clear 4 min ago · freed 900 MB.")
    #expect(AutoClearText.status(last: nil, nextPossible: nil, now: start) == nil)
}
