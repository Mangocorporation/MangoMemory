import AppKit
import MangoMemoryKit

/// Where numbers come from: the kernel, or fixed sample numbers for snapshots and the self-test.
nonisolated protocol MemorySource: Sendable {
    func stats() -> MemoryStats?
    func topApps(_ limit: Int, apps: [AppUsage], excluding: Int32) -> [AppUsage]
    /// MangoMemory's own CPU seconds so far and footprint.
    func selfUsage() -> (cpu: TimeInterval, footprint: UInt64)
}

nonisolated struct SystemMemorySource: MemorySource {
    func stats() -> MemoryStats? { SystemMemory.stats() }

    func topApps(_ limit: Int, apps: [AppUsage], excluding: Int32) -> [AppUsage] {
        AppUsageRanking.top(limit, samples: SystemMemory.processes(), apps: apps, excluding: excluding)
    }

    func selfUsage() -> (cpu: TimeInterval, footprint: UInt64) { SystemMemory.selfUsage() }
}

/// Live memory numbers and Top Apps, refreshed every refresh interval off the main thread.
@Observable
final class MemoryMonitor {
    static let refreshChoices: [Int] = [1, 2, 5, 10]

    /// What the menu bar item shows. Changes every refresh.
    private(set) var stats: MemoryStats?
    /// What the memory window shows. Changes only while it is open, so a closed
    /// window never redraws or animates (that cost 23 % CPU, docs/FIXLOG.md).
    private(set) var windowStats: MemoryStats?
    private(set) var topApps: [AppUsage] = []
    /// The last hour, for the chart. Like `windowStats`, it changes only while the window is open.
    private(set) var windowHistory = PressureHistory()
    /// "MangoMemory: 0.2 % CPU · 28 MB", read only while the window is open (S-022).
    private(set) var selfUsageLine: String?
    @ObservationIgnored private var history = PressureHistory()
    @ObservationIgnored private var lastCPU: (cpu: TimeInterval, at: TimeInterval)?
    /// Seconds between readings (Settings > General). Saved in Store.defaults.
    var refreshInterval: Int {
        didSet {
            Store.defaults.set(refreshInterval, forKey: "refreshInterval")
            restart()
        }
    }

    /// True while the memory window is open. Top Apps is read only then:
    /// the menu bar item needs just the totals.
    var windowIsOpen = false {
        // Fresh Top Apps at once on open. Not when stopped: snapshots stage their own numbers.
        didSet { if windowIsOpen && !oldValue && loop != nil { Task { await refresh() } } }
    }

    /// Called with every reading, open window or not (automatic clearing).
    var onStats: ((MemoryStats) -> Void)?

    /// The drop-down and the pinned window can both be open for a moment.
    private var openWindows = 0

    func windowAppeared() {
        openWindows += 1
        windowIsOpen = true
    }

    func windowDisappeared() {
        openWindows = max(0, openWindows - 1)
        windowIsOpen = openWindows > 0
    }

    private let source: any MemorySource
    private var loop: Task<Void, Never>?

    init(source: any MemorySource) {
        self.source = source
        let saved = Store.defaults.integer(forKey: "refreshInterval")
        refreshInterval = Self.refreshChoices.contains(saved) ? saved : 2
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled, let self {
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.refreshInterval))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    private func restart() {
        guard loop != nil else { return }
        loop?.cancel()
        loop = nil
        start()
    }

    func refresh() async {
        let apps = windowIsOpen ? Self.runningApps() : nil
        let source = source
        let me = ProcessInfo.processInfo.processIdentifier
        let open = windowIsOpen
        let (stats, top, own) = await Task.detached(priority: .utility) {
            (source.stats(), apps.map { source.topApps(5, apps: $0, excluding: me) }, open ? source.selfUsage() : nil)
        }.value
        if let stats { history.append(stats, at: .now) }
        if windowIsOpen, history != windowHistory { windowHistory = history }
        if let own { updateSelfUsage(own) }
        // Assign only changes: every assignment redraws the views that read it.
        if let stats, stats != self.stats { self.stats = stats }
        if windowIsOpen, let stats, stats != windowStats { windowStats = stats }
        if let top, top != topApps { topApps = top }
        if let stats { onStats?(stats) }
    }

    /// The biggest running apps, read off the main thread. For measuring an app when it quits.
    func appSizes() async -> [AppUsage] {
        let apps = Self.runningApps()
        let source = source
        let me = ProcessInfo.processInfo.processIdentifier
        return await Task.detached(priority: .utility) { source.topApps(10, apps: apps, excluding: me) }.value
    }

    /// Marks a clear on the chart.
    func recordClean(at date: Date) {
        history.cleared(at: date)
        if windowIsOpen { windowHistory = history }
    }

    private func updateSelfUsage(_ own: (cpu: TimeInterval, footprint: UInt64)) {
        let now = ProcessInfo.processInfo.systemUptime
        defer { lastCPU = (own.cpu, now) }
        guard let last = lastCPU, now > last.at else { return }
        let percent = max(0, (own.cpu - last.cpu) / (now - last.at) * 100)
        let line = SelfUsageText.line(cpuPercent: percent, footprint: own.footprint)
        if line != selfUsageLine { selfUsageLine = line }
    }

    /// Snapshot mode sets the numbers it wants to show.
    func show(_ stats: MemoryStats, topApps: [AppUsage], history: PressureHistory = PressureHistory(),
              selfUsage: String? = nil) {
        self.stats = stats
        self.windowStats = stats
        self.topApps = topApps
        self.history = history
        windowHistory = history
        selfUsageLine = selfUsage
    }

    /// Apps with a Dock icon. Menu bar apps and daemons are left out.
    private static func runningApps() -> [AppUsage] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .map { AppUsage(pid: $0.processIdentifier, name: $0.localizedName ?? "App",
                            bundlePath: $0.bundleURL?.path, bytes: 0) }
    }
}
