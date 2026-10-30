import Foundation
import Testing
@testable import MangoCleanerKit

private let gb: UInt64 = 1_073_741_824

private func stats(available: UInt64, pressure: Int) -> MemoryStats {
    MemoryStats(total: 24 * gb, app: 10 * gb, wired: 3 * gb, compressed: 4 * gb,
                fileCache: available / 2, free: available - available / 2, swapUsed: 0,
                level: .normal, pressurePercent: pressure)
}

@Test("A clear reports what it freed and how pressure moved")
func summary() {
    let result = CleanResult(date: .now, trigger: .button,
                             before: stats(available: 3 * gb, pressure: 62),
                             after: stats(available: 3 * gb + 1_288_490_189, pressure: 48))
    #expect(result.freed == 1_288_490_189)
    #expect(result.summary == "Freed 1.2 GB · pressure 62 % → 48 %")
}

@Test("Under 50 MB, it says there was nothing much to clear")
func honest() {
    let result = CleanResult(date: .now, trigger: .button,
                             before: stats(available: 3 * gb, pressure: 40),
                             after: stats(available: 3 * gb + 10_000_000, pressure: 40))
    #expect(result.summary == "Nothing much to clear")
}

@Test("Memory taken by other apps meanwhile never shows as negative")
func neverNegative() {
    let result = CleanResult(date: .now, trigger: .menu,
                             before: stats(available: 3 * gb, pressure: 40),
                             after: stats(available: 2 * gb, pressure: 45))
    #expect(result.freed == 0)
    #expect(result.summary == "Nothing much to clear")
}
