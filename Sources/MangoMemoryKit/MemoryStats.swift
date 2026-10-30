import Foundation

/// How hard macOS works to find memory (docs/GLOSSARY.md: Normal / High / Critical).
public enum PressureLevel: String, Sendable, CaseIterable {
    case normal, high, critical

    /// From `kern.memorystatus_vm_pressure_level`: 1 normal, 2 warn, 4 critical.
    public init(kernelLevel: Int32) {
        switch kernelLevel {
        case 4...: self = .critical
        case 2, 3: self = .high
        default: self = .normal
        }
    }

    public var title: String {
        switch self {
        case .normal: "Normal"
        case .high: "High"
        case .critical: "Critical"
        }
    }
}

/// Raw page counts from `host_statistics64(HOST_VM_INFO64)`.
public struct VMCounts: Sendable, Equatable {
    public var active: UInt64
    public var inactive: UInt64
    public var speculative: UInt64
    public var wired: UInt64
    public var compressed: UInt64
    public var purgeable: UInt64
    public var external: UInt64

    public init(active: UInt64, inactive: UInt64, speculative: UInt64, wired: UInt64,
                compressed: UInt64, purgeable: UInt64, external: UInt64) {
        self.active = active
        self.inactive = inactive
        self.speculative = speculative
        self.wired = wired
        self.compressed = compressed
        self.purgeable = purgeable
        self.external = external
    }
}

/// One reading of the Mac's memory, in bytes. The five parts (app, wired,
/// compressed, file cache, free) add up to total.
public struct MemoryStats: Sendable, Equatable {
    public var total: UInt64
    public var app: UInt64
    public var wired: UInt64
    public var compressed: UInt64
    public var fileCache: UInt64
    public var free: UInt64
    public var swapUsed: UInt64
    public var level: PressureLevel
    /// 0–100, from `kern.memorystatus_level` (100 minus the percent available to apps).
    public var pressurePercent: Int

    public init(total: UInt64, app: UInt64, wired: UInt64, compressed: UInt64, fileCache: UInt64,
                free: UInt64, swapUsed: UInt64, level: PressureLevel, pressurePercent: Int) {
        self.total = total
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.fileCache = fileCache
        self.free = free
        self.swapUsed = swapUsed
        self.level = level
        self.pressurePercent = pressurePercent
    }

    /// Free plus file cache: what apps can get without compressing or swapping.
    /// The menu bar item shows this.
    public var available: UInt64 { free + fileCache }

    /// Builds the breakdown with Stats' formulas (docs/research/memory-cleaners.md):
    /// used = active + inactive + speculative + wired + compressed − purgeable − external,
    /// app = used − wired − compressed, file cache = purgeable + external,
    /// free = total − used − file cache.
    public init(counts c: VMCounts, pageSize: UInt64, total: UInt64, swapUsed: UInt64,
                kernelLevel: Int32, availablePercent: Int32) {
        let pages = c.active + c.inactive + c.speculative + c.wired + c.compressed
        let notUsed = c.purgeable + c.external
        let used = (pages > notUsed ? pages - notUsed : 0) * pageSize
        let wired = c.wired * pageSize
        let compressed = c.compressed * pageSize
        let cache = min(notUsed * pageSize, total)
        let usedCapped = min(used, total - cache)
        self.init(
            total: total,
            app: usedCapped > wired + compressed ? usedCapped - wired - compressed : 0,
            wired: min(wired, usedCapped),
            compressed: min(compressed, usedCapped > wired ? usedCapped - wired : 0),
            fileCache: cache,
            free: total - usedCapped - cache,
            swapUsed: swapUsed,
            level: PressureLevel(kernelLevel: kernelLevel),
            pressurePercent: max(0, min(100, 100 - Int(availablePercent)))
        )
    }
}
