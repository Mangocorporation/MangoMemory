import Testing
@testable import MangoCleanerKit

private let page: UInt64 = 16_384
private let gb: UInt64 = 1_073_741_824

private func counts(active: UInt64 = 300_000, inactive: UInt64 = 280_000, speculative: UInt64 = 10_000,
                    wired: UInt64 = 330_000, compressed: UInt64 = 250_000,
                    purgeable: UInt64 = 20_000, external: UInt64 = 170_000) -> VMCounts {
    VMCounts(active: active, inactive: inactive, speculative: speculative, wired: wired,
             compressed: compressed, purgeable: purgeable, external: external)
}

@Test("The five parts add up to total")
func partsSumToTotal() {
    let stats = MemoryStats(counts: counts(), pageSize: page, total: 24 * gb, swapUsed: 0,
                            kernelLevel: 1, availablePercent: 60)
    #expect(stats.app + stats.wired + stats.compressed + stats.fileCache + stats.free == stats.total)
}

@Test("File cache is purgeable plus external pages, and counts as available")
func fileCache() {
    let stats = MemoryStats(counts: counts(), pageSize: page, total: 24 * gb, swapUsed: 0,
                            kernelLevel: 1, availablePercent: 60)
    #expect(stats.fileCache == 190_000 * page)
    #expect(stats.available == stats.free + stats.fileCache)
}

@Test("App memory is used minus wired minus compressed")
func appMemory() {
    let stats = MemoryStats(counts: counts(), pageSize: page, total: 24 * gb, swapUsed: 0,
                            kernelLevel: 1, availablePercent: 60)
    let used = (300_000 + 280_000 + 10_000 + 330_000 + 250_000 - 190_000) * page
    #expect(stats.app == used - 330_000 * page - 250_000 * page)
}

@Test("Counts larger than total never go negative")
func overfull() {
    let stats = MemoryStats(counts: counts(active: 2_000_000), pageSize: page, total: 8 * gb,
                            swapUsed: 0, kernelLevel: 4, availablePercent: 5)
    #expect(stats.free == 0)
    #expect(stats.app + stats.wired + stats.compressed + stats.fileCache + stats.free == stats.total)
}

@Test("Kernel pressure levels map to Normal, High, Critical", arguments: [
    (Int32(0), PressureLevel.normal), (1, .normal), (2, .high), (4, .critical),
])
func levels(kernel: Int32, expected: PressureLevel) {
    #expect(PressureLevel(kernelLevel: kernel) == expected)
}

@Test("Pressure percent is 100 minus the available percent, clamped")
func percent() {
    let make = { (available: Int32) in
        MemoryStats(counts: counts(), pageSize: page, total: 24 * gb, swapUsed: 0,
                    kernelLevel: 1, availablePercent: available).pressurePercent
    }
    #expect(make(59) == 41)
    #expect(make(120) == 0)
    #expect(make(-5) == 100)
}
