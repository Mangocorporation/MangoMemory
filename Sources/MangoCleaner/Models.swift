import Foundation
import Observation

/// App-wide state that the menu bar label, the memory window, and Settings share.
@Observable
final class AppModel {
    let monitor: MemoryMonitor
    let quitFlow: QuitFlow
    let cleanFlow: CleanFlow
    /// The Top Apps row under the pointer or selected with the arrow keys.
    var focusedApp: Int32?
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: Store.defaults.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { Store.defaults.set(settingsTab.rawValue, forKey: "settings.tab") }
    }

    /// Test runs (APP_STORE set) read sample numbers, quit nothing, and never run purge.
    init() {
        if Store.isOverridden {
            monitor = MemoryMonitor(source: SampleMemorySource())
            quitFlow = QuitFlow(quitter: FakeQuitter())
            cleanFlow = CleanFlow(clearer: FakeCacheClearer()) { SampleData.stats() }
        } else {
            let monitor = MemoryMonitor(source: SystemMemorySource())
            self.monitor = monitor
            quitFlow = QuitFlow(quitter: SystemQuitter())
            cleanFlow = CleanFlow(clearer: HelperCacheClearer()) {
                let stats = await Task.detached(priority: .userInitiated) { SystemMemory.stats() }.value
                await monitor.refresh()
                return stats
            }
        }
        monitor.start()
    }
}
