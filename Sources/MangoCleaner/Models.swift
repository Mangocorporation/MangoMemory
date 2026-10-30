import Foundation
import MangoCleanerKit
import Observation
import ServiceManagement

/// App-wide state that the menu bar label, the memory window, and Settings share.
@Observable
final class AppModel {
    let monitor: MemoryMonitor
    let quitFlow: QuitFlow
    let cleanFlow: CleanFlow
    let autoClear: AutoClear
    let alerts: PressureAlerts
    /// Same settings on every Mac, through iCloud Drive.
    private(set) var settingsSync: SettingsSync!
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
    /// The memory window floats on its own, outside the menu bar (S-025).
    var pinned = false

    /// What the menu bar item shows next to its glyph (S-023).
    var menuBarText: MenuBarText = MenuBarText(rawValue: Store.defaults.string(forKey: "menuBar.text") ?? "") ?? .available {
        didSet { Store.defaults.set(menuBarText.rawValue, forKey: "menuBar.text") }
    }
    var largeMenuBarText: Bool = Store.defaults.bool(forKey: "menuBar.large") {
        didSet { Store.defaults.set(largeMenuBarText, forKey: "menuBar.large") }
    }

    /// Open at login (S-024), through SMAppService. Test runs only pretend.
    var openAtLogin: Bool {
        get {
            access(keyPath: \.openAtLogin)
            return Store.isOverridden ? testOpenAtLogin : SMAppService.mainApp.status == .enabled
        }
        set {
            withMutation(keyPath: \.openAtLogin) {
                if Store.isOverridden {
                    testOpenAtLogin = newValue
                } else {
                    try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                }
            }
        }
    }
    @ObservationIgnored private var testOpenAtLogin = false
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
        settingsSync = SettingsSync(read: { [unowned self] in syncedValues() },
                                    apply: { [unowned self] in applySynced($0) })
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

    /// Every setting that syncs, read from where it lives.
    private func syncedValues() -> SyncedSettings.Values {
        SyncedSettings.Values(
            refreshInterval: monitor.refreshInterval, menuBarText: menuBarText.rawValue,
            largeMenuBarText: largeMenuBarText, openAtLogin: openAtLogin, shortcut: shortcut,
            clearWhenPressureHigh: autoClear.whenPressureHigh, highFor: autoClear.highFor,
            clearAfterBigQuit: autoClear.afterBigQuit, bigApp: autoClear.bigApp,
            notifyCritical: alerts.whenCritical, notifyHigh: alerts.whenHigh,
            accent: ThemeStore.shared.themeID)
    }

    /// Settings from another Mac. Sets only what differs, so nothing restarts for no reason.
    private func applySynced(_ v: SyncedSettings.Values) {
        if MemoryMonitor.refreshChoices.contains(v.refreshInterval), v.refreshInterval != monitor.refreshInterval {
            monitor.refreshInterval = v.refreshInterval
        }
        if let text = MenuBarText(rawValue: v.menuBarText), text != menuBarText { menuBarText = text }
        if v.largeMenuBarText != largeMenuBarText { largeMenuBarText = v.largeMenuBarText }
        if v.openAtLogin != openAtLogin { openAtLogin = v.openAtLogin }
        if v.shortcut != shortcut { shortcut = v.shortcut }
        if v.clearWhenPressureHigh != autoClear.whenPressureHigh { autoClear.whenPressureHigh = v.clearWhenPressureHigh }
        if AutoClearRules.durations.contains(v.highFor), v.highFor != autoClear.highFor { autoClear.highFor = v.highFor }
        if v.clearAfterBigQuit != autoClear.afterBigQuit { autoClear.afterBigQuit = v.clearAfterBigQuit }
        if AutoClearRules.thresholds.contains(v.bigApp), v.bigApp != autoClear.bigApp { autoClear.bigApp = v.bigApp }
        if v.notifyCritical != alerts.whenCritical { alerts.whenCritical = v.notifyCritical }
        if v.notifyHigh != alerts.whenHigh { alerts.whenHigh = v.notifyHigh }
        if Theme.all.contains(where: { $0.id == v.accent }), v.accent != ThemeStore.shared.themeID {
            ThemeStore.shared.themeID = v.accent
        }
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
