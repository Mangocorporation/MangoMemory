import Foundation
import MangoCleanerKit
import Observation

/// App-wide state that the menu bar label, the memory window, and Settings share.
@Observable
final class AppModel {
    let monitor: MemoryMonitor
    let quitFlow: QuitFlow
    let cleanFlow: CleanFlow
    let autoClear: AutoClear
    let alerts: PressureAlerts
    /// The fakes behind a test run, so the self-test can see what they were asked.
    let fakes: (quitter: FakeQuitter, clearer: FakeCacheClearer, notifier: FakeNotifier)?
    /// Opens the memory window from any app (S-018). Nil: no shortcut.
    var shortcut: Shortcut? {
        didSet {
            Store.defaults.set(shortcut.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "shortcut")
            registerShortcut()
        }
    }
    /// True when another app already uses the shortcut.
    private(set) var shortcutTaken = false
    private let hotKey: GlobalHotKey?

    /// The Top Apps row under the pointer or selected with the arrow keys.
    var focusedApp: Int32?
    /// The app waiting for its "Force Quit …?" confirmation (S-007).
    var confirming: AppUsage?
    /// The popover that explains each number (S-021).
    var showingHelp = false
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: Store.defaults.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { Store.defaults.set(settingsTab.rawValue, forKey: "settings.tab") }
    }

    /// Test runs (APP_STORE set) read sample numbers, quit nothing, and never run purge.
    init() {
        if Store.isOverridden {
            monitor = MemoryMonitor(source: SampleMemorySource())
            let fakes = (quitter: FakeQuitter(), clearer: FakeCacheClearer(), notifier: FakeNotifier())
            self.fakes = fakes
            quitFlow = QuitFlow(quitter: fakes.quitter)
            cleanFlow = CleanFlow(clearer: fakes.clearer) { SampleData.stats() }
        } else {
            fakes = nil
            let monitor = MemoryMonitor(source: SystemMemorySource())
            self.monitor = monitor
            quitFlow = QuitFlow(quitter: SystemQuitter())
            cleanFlow = CleanFlow(clearer: HelperCacheClearer()) {
                let stats = await Task.detached(priority: .userInitiated) { SystemMemory.stats() }.value
                await monitor.refresh()
                return stats
            }
        }
        autoClear = AutoClear(cleanFlow: cleanFlow) { [monitor] in await monitor.appSizes() }
        let notifier: any Notifier
        if let fakes {
            notifier = fakes.notifier
        } else {
            let system = SystemNotifier()
            system.onQuit = { [quitFlow] app in quitFlow.quit(app) }
            notifier = system
        }
        alerts = PressureAlerts(notifier: notifier) { [monitor] in await monitor.appSizes().first }
        cleanFlow.whenCleared { [weak monitor] result in monitor?.recordClean(at: result.date) }
        monitor.onStats = { [weak autoClear, weak alerts] stats in
            autoClear?.reading(stats.level)
            alerts?.reading(stats.level)
        }
        // No saved value: the default. Saved but empty: removed on purpose.
        if let data = Store.defaults.data(forKey: "shortcut") {
            shortcut = try? JSONDecoder().decode(Shortcut.self, from: data)
        } else {
            shortcut = .standard
        }
        // Test runs never take a system-wide shortcut from the real app.
        hotKey = Store.isOverridden ? nil : GlobalHotKey { MenuBarItem.toggle() }
        registerShortcut()
        monitor.start()
    }

    /// Off while Settings records a new one, so typing it does not open the window.
    func pauseShortcut(_ paused: Bool) {
        paused ? hotKey?.unregister() : registerShortcut()
    }

    private func registerShortcut() {
        guard let hotKey else { return }
        shortcutTaken = !hotKey.register(shortcut)
    }

    /// ↑ and ↓ in the memory window (S-019).
    func moveFocus(_ step: Int) {
        let apps = monitor.topApps
        guard !apps.isEmpty else { return }
        let index = apps.firstIndex { $0.pid == focusedApp }.map { $0 + step } ?? (step > 0 ? 0 : apps.count - 1)
        focusedApp = apps[max(0, min(apps.count - 1, index))].pid
    }

    /// Return in the memory window: Quit, or ask to Force Quit an app that refused.
    func quitFocused() {
        guard let app = monitor.topApps.first(where: { $0.pid == focusedApp }) else { return }
        switch quitFlow.states[app.pid] {
        case .refused?: confirming = app
        case nil: quitFlow.quit(app)
        case .quitting?: break
        }
    }
}
