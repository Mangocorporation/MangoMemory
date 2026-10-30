import AppKit
import MangoCleanerKit

/// Clears the file cache on its own (S-014 to S-016): when pressure stays high,
/// and after a big app quits. The rules live in `AutoClearRules`; this keeps the
/// settings, feeds the rules, and starts the clears.
@Observable
final class AutoClear {
    private(set) var rules = AutoClearRules()
    /// The last automatic clear, for Settings > Automation.
    private(set) var lastResult: CleanResult?

    var whenPressureHigh: Bool {
        get { rules.whenPressureHigh }
        set { rules.whenPressureHigh = newValue; save() }
    }
    var highFor: TimeInterval {
        get { rules.highFor }
        set { rules.highFor = newValue; save() }
    }
    var afterBigQuit: Bool {
        get { rules.afterBigQuit }
        set { rules.afterBigQuit = newValue; save(); watchApps() }
    }
    var bigApp: UInt64 {
        get { rules.bigApp }
        set { rules.bigApp = newValue; save() }
    }

    private let cleanFlow: CleanFlow
    private let appSizes: () async -> [AppUsage]
    private var sizeLoop: Task<Void, Never>?
    private var quitObserver: NSObjectProtocol?

    init(cleanFlow: CleanFlow, appSizes: @escaping () async -> [AppUsage]) {
        self.cleanFlow = cleanFlow
        self.appSizes = appSizes
        let defaults = Store.defaults
        rules.whenPressureHigh = defaults.bool(forKey: "auto.pressure")
        let duration = defaults.double(forKey: "auto.highFor")
        if AutoClearRules.durations.contains(duration) { rules.highFor = duration }
        rules.afterBigQuit = defaults.bool(forKey: "auto.afterQuit")
        let threshold = UInt64(defaults.integer(forKey: "auto.bigApp"))
        if AutoClearRules.thresholds.contains(threshold) { rules.bigApp = threshold }

        // A clear from the button or the menu starts the shared cooldown too.
        // Automatic clears already started it when they began (see `start`).
        cleanFlow.onCleared = { [weak self] result in
            guard let self else { return }
            if result.trigger == .pressure || result.trigger == .afterQuit {
                lastResult = result
            } else {
                rules.cleared(at: result.date)
            }
        }
        quitObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated { if let pid { _ = self?.appQuit(pid: pid) } }
        }
        watchApps()
    }

    /// Every pressure reading comes here. Returns the clear it started, if any.
    @discardableResult
    func reading(_ level: PressureLevel, at now: Date = .now) -> Task<Void, Never>? {
        guard rules.pressure(level, at: now) else { return nil }
        return start(.pressure, at: now)
    }

    @discardableResult
    func appQuit(pid: Int32, at now: Date = .now) -> Task<Void, Never>? {
        guard rules.appQuit(pid: pid, at: now) else { return nil }
        return start(.afterQuit, at: now)
    }

    /// The sizes the next quit is measured against. The self-test sets its own.
    func setAppSizes(_ apps: [AppUsage]) { rules.appSizes(apps) }

    /// Snapshot mode shows a last automatic clear and a running cooldown.
    func show(_ result: CleanResult?, settings: (Bool, Bool)) {
        sizeLoop?.cancel()
        rules = AutoClearRules()
        rules.whenPressureHigh = settings.0
        rules.afterBigQuit = settings.1
        if let result { rules.cleared(at: result.date) }
        lastResult = result
    }

    private func start(_ trigger: CleanTrigger, at now: Date) -> Task<Void, Never> {
        // Count the attempt, so a helper that is not ready is not asked again every reading.
        rules.cleared(at: now)
        return Task { await cleanFlow.clear(trigger: trigger) }
    }

    /// While "after a big app quits" is on, reads app sizes every 15 seconds.
    private func watchApps() {
        sizeLoop?.cancel()
        sizeLoop = nil
        guard rules.afterBigQuit else { return }
        sizeLoop = Task { [weak self] in
            while !Task.isCancelled, let self {
                let apps = await appSizes()
                if !Task.isCancelled { rules.appSizes(apps) }
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    private func save() {
        let defaults = Store.defaults
        defaults.set(rules.whenPressureHigh, forKey: "auto.pressure")
        defaults.set(rules.highFor, forKey: "auto.highFor")
        defaults.set(rules.afterBigQuit, forKey: "auto.afterQuit")
        defaults.set(Int(rules.bigApp), forKey: "auto.bigApp")
    }
}
