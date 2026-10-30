import Testing
@testable import MangoCleanerKit

private let apps = [
    AppUsage(pid: 10, name: "Safari", bundlePath: nil, bytes: 0),
    AppUsage(pid: 20, name: "Mail", bundlePath: nil, bytes: 0),
    AppUsage(pid: 30, name: "MangoCleaner", bundlePath: nil, bytes: 0),
    AppUsage(pid: 40, name: "Notes", bundlePath: nil, bytes: 0),
]

@Test("Helper processes count toward the app responsible for them")
func groupsHelpers() {
    let samples = [
        ProcessSample(pid: 10, responsiblePID: 10, footprint: 500),
        ProcessSample(pid: 11, responsiblePID: 10, footprint: 2_000), // a Safari web page
        ProcessSample(pid: 20, responsiblePID: 20, footprint: 1_000),
    ]
    let top = AppUsageRanking.top(5, samples: samples, apps: apps, excluding: 30)
    #expect(top.map(\.name) == ["Safari", "Mail"])
    #expect(top.first?.bytes == 2_500)
}

@Test("MangoCleaner never lists itself, and daemons are left out")
func excludes() {
    let samples = [
        ProcessSample(pid: 30, responsiblePID: 30, footprint: 9_000),
        ProcessSample(pid: 99, responsiblePID: 1, footprint: 8_000),
        ProcessSample(pid: 40, responsiblePID: 40, footprint: 100),
    ]
    let top = AppUsageRanking.top(5, samples: samples, apps: apps, excluding: 30)
    #expect(top.map(\.name) == ["Notes"])
}

@Test("Keeps the five biggest, largest first")
func limits() {
    let many = (1...8).map { AppUsage(pid: Int32($0), name: "App \($0)", bundlePath: nil, bytes: 0) }
    let samples = (1...8).map { ProcessSample(pid: Int32($0), responsiblePID: Int32($0), footprint: UInt64($0) * 10) }
    let top = AppUsageRanking.top(5, samples: samples, apps: many, excluding: 0)
    #expect(top.map(\.bytes) == [80, 70, 60, 50, 40])
}
