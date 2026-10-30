import Foundation
import Testing
@testable import MangoMemoryKit

private let gb: UInt64 = 1_073_741_824

@Test("Each choice shows the expected menu bar text")
func menuBarText() {
    let stats = MemoryStats(total: 24 * gb, app: 10 * gb, wired: 3 * gb, compressed: 4 * gb,
                            fileCache: 3 * gb, free: 4 * gb, swapUsed: 0, level: .normal, pressurePercent: 34)
    #expect(MenuBarText.available.text(for: stats) == "7.0 GB")
    #expect(MenuBarText.pressure.text(for: stats) == "34 %")
    #expect(MenuBarText.iconOnly.text(for: stats) == nil)
    #expect(MenuBarText.available.text(for: nil) == nil)
}
