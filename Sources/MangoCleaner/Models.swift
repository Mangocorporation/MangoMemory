import Foundation
import Observation

/// App-wide state that the menu bar label, the memory window, and Settings share.
@Observable
final class AppModel {
    let monitor: MemoryMonitor
    let quitFlow: QuitFlow
    /// The Top Apps row under the pointer or selected with the arrow keys.
    var focusedApp: Int32?
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: Store.defaults.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { Store.defaults.set(settingsTab.rawValue, forKey: "settings.tab") }
    }

    /// Test runs (APP_STORE set) read sample numbers and quit nothing.
    init() {
        if Store.isOverridden {
            monitor = MemoryMonitor(source: SampleMemorySource())
            quitFlow = QuitFlow(quitter: FakeQuitter())
        } else {
            monitor = MemoryMonitor(source: SystemMemorySource())
            quitFlow = QuitFlow(quitter: SystemQuitter())
        }
        monitor.start()
    }
}
