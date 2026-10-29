import Foundation
import Observation

/// App-wide state that the menu bar label, the memory window, and Settings share.
@Observable
final class AppModel {
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: Store.defaults.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { Store.defaults.set(settingsTab.rawValue, forKey: "settings.tab") }
    }
}
