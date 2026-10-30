import Foundation
import Testing
@testable import MangoCleanerKit

private let start = Date(timeIntervalSinceReferenceDate: 0)

@Test("Alerts once when pressure turns critical, not on every reading")
func oncePerChange() {
    var rules = PressureAlertRules()
    do { let level = rules.reading(.normal, at: start); #expect(level == nil) }
    do { let level = rules.reading(.critical, at: start + 2); #expect(level == .critical) }
    do { let level = rules.reading(.critical, at: start + 4); #expect(level == nil) }
}

@Test("Quiet for 30 minutes after an alert")
func quietPeriod() {
    var rules = PressureAlertRules()
    _ = rules.reading(.critical, at: start)
    _ = rules.reading(.normal, at: start + 60)
    do { let level = rules.reading(.critical, at: start + 120); #expect(level == nil) }
    _ = rules.reading(.normal, at: start + 1700)
    do { let level = rules.reading(.critical, at: start + 1801); #expect(level == .critical) }
}

@Test("High alerts only when turned on, and Critical still alerts after it")
func highThenCritical() {
    var rules = PressureAlertRules()
    do { let level = rules.reading(.high, at: start); #expect(level == nil) }
    rules = PressureAlertRules()
    rules.whenHigh = true
    do { let level = rules.reading(.high, at: start); #expect(level == .high) }
    do { let level = rules.reading(.critical, at: start + 60); #expect(level == .critical) }
}

@Test("Off means never")
func alertsOff() {
    var rules = PressureAlertRules()
    rules.whenCritical = false
    do { let level = rules.reading(.critical, at: start); #expect(level == nil) }
}

@Test("The alert names the app using the most memory")
func alertText() {
    let safari = AppUsage(pid: 1, name: "Safari", bundlePath: nil, bytes: 6_549_825_126)
    #expect(PressureAlertText.title(.critical) == "Memory pressure is Critical")
    #expect(PressureAlertText.body(top: safari) == "Safari uses the most memory: 6.1 GB.")
}
