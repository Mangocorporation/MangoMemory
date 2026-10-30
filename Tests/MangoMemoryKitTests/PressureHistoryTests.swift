import Foundation
import Testing
@testable import MangoMemoryKit

private let start = Date(timeIntervalSinceReferenceDate: 600)

private func stats(_ percent: Int, _ level: PressureLevel = .normal) -> MemoryStats {
    MemoryStats(total: 100, app: 0, wired: 0, compressed: 0, fileCache: 0, free: 100, swapUsed: 0,
                level: level, pressurePercent: percent)
}

@Test("Keeps one sample per refresh for an hour and drops older ones")
func keepsAnHour() {
    var history = PressureHistory()
    for second in stride(from: 0.0, to: 4000, by: 2) {
        history.append(stats(30), at: start + second)
    }
    #expect(history.samples.count == 1801)
    #expect(history.samples.first?.date == start + 3998 - 3600)
}

@Test("Clears older than an hour are dropped")
func dropsOldClears() {
    var history = PressureHistory()
    history.cleared(at: start)
    history.cleared(at: start + 3000)
    history.append(stats(30), at: start + 3700)
    #expect(history.clears == [start + 3000])
}

@Test("Each minute shows its highest percent and worst level")
func perMinute() {
    var history = PressureHistory()
    history.append(stats(30), at: start)
    history.append(stats(70, .high), at: start + 20)
    history.append(stats(40), at: start + 40)
    history.append(stats(20), at: start + 60)
    let minutes = history.minutes()
    #expect(minutes.count == 2)
    #expect(minutes[0].percent == 70 && minutes[0].level == .high)
    #expect(minutes[1].percent == 20 && minutes[1].level == .normal)
}

@Test("MangoMemory's own use reads like the footer")
func selfUsage() {
    #expect(SelfUsageText.line(cpuPercent: 0.24, footprint: 29_360_128) == "MangoMemory: 0.2 % CPU · 28 MB")
}

@Test("The CPU figure averages the last 10 seconds, so a short burst doesn't jump it")
func cpuAverage() {
    // 2 seconds apart; one burst of 0.16 s CPU between 4 and 6 s, otherwise 0.01 s each.
    let readings: [(cpu: TimeInterval, at: TimeInterval)] = [
        (0.00, 0), (0.01, 2), (0.02, 4), (0.18, 6), (0.19, 8), (0.20, 10), (0.21, 12),
    ]
    #expect(SelfUsageText.cpuPercent(Array(readings.prefix(1))) == nil)
    // The 2-second figure right after the burst would read 8 %.
    #expect(abs(SelfUsageText.cpuPercent(Array(readings[2...3]))! - 8) < 0.001)
    // Over the last 10 seconds (2 to 12 s): 0.20 s of CPU in 10 s = 2 %.
    #expect(abs(SelfUsageText.cpuPercent(readings)! - 2) < 0.001)
}
