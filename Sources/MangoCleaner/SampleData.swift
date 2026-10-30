import Foundation
import MangoCleanerKit

/// Fixed numbers for snapshots and the self-test (any run with APP_STORE set),
/// so pictures are stable and nothing real is quit.
nonisolated enum SampleData {
    private static let gb: Double = 1_073_741_824

    static func stats(level: PressureLevel = .normal) -> MemoryStats {
        func bytes(_ value: Double) -> UInt64 { UInt64(value * gb) }
        let percent = [PressureLevel.normal: 34, .high: 68, .critical: 91][level] ?? 34
        return MemoryStats(total: bytes(24), app: bytes(9.8), wired: bytes(3.6), compressed: bytes(4.2),
                           fileCache: bytes(3.0), free: bytes(3.4), swapUsed: bytes(1.2),
                           level: level, pressurePercent: percent)
    }

    /// Real app names with their bundles, when installed, so icons show.
    static let apps: [AppUsage] = [
        ("Safari", "/Applications/Safari.app", 6.1),
        ("Xcode", "/Applications/Xcode.app", 3.9),
        ("Google Chrome With a Very Long Name for Truncation", "/Applications/Google Chrome.app", 2.4),
        ("Mail", "/System/Applications/Mail.app", 0.8),
        ("Music", "/System/Applications/Music.app", 0.4),
    ].enumerated().map { index, app in
        AppUsage(pid: Int32(90_001 + index), name: app.0, bundlePath: app.1, bytes: UInt64(app.2 * gb))
    }
}

nonisolated struct SampleMemorySource: MemorySource {
    func stats() -> MemoryStats? { SampleData.stats() }

    func topApps(_ limit: Int, apps: [AppUsage], excluding: Int32) -> [AppUsage] {
        Array(SampleData.apps.prefix(limit))
    }
}
