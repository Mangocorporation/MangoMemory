import Foundation
import Testing
@testable import MangoMemoryKit

private let gb: UInt64 = 1_073_741_824

private func stats(fileCache: UInt64, free: UInt64, pressure: Int) -> MemoryStats {
    MemoryStats(total: 24 * gb, app: 10 * gb, wired: 3 * gb, compressed: 4 * gb,
                fileCache: fileCache, free: free, swapUsed: 0,
                level: .normal, pressurePercent: pressure)
}

@Test("A clear reports the file cache it emptied, though available memory stays the same")
func summary() {
    // What purge does: file cache becomes free memory. Available (free + cache) barely moves.
    let before = stats(fileCache: 3 * gb, free: 2 * gb, pressure: 53)
    let after = stats(fileCache: 3 * gb - 2_254_857_830, free: 2 * gb + 2_254_857_830, pressure: 52)
    #expect(before.available == after.available)
    let result = CleanResult(date: .now, trigger: .button, before: before, after: after)
    #expect(result.cleared == 2_254_857_830)
    #expect(result.summary == "Cleared 2.1 GB · pressure 53 % → 52 %")
}

@Test("Under 50 MB, it says there was nothing much to clear")
func honest() {
    let result = CleanResult(date: .now, trigger: .button,
                             before: stats(fileCache: 200_000_000, free: 2 * gb, pressure: 40),
                             after: stats(fileCache: 190_000_000, free: 2 * gb + 10_000_000, pressure: 40))
    #expect(result.summary == "Nothing much to clear")
}

@Test("File cache that grew meanwhile never shows as negative")
func neverNegative() {
    let result = CleanResult(date: .now, trigger: .menu,
                             before: stats(fileCache: gb, free: 3 * gb, pressure: 40),
                             after: stats(fileCache: 2 * gb, free: 2 * gb, pressure: 45))
    #expect(result.cleared == 0)
    #expect(result.summary == "Nothing much to clear")
}
