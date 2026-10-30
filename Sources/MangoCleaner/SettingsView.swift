import MangoCleanerKit
import SwiftUI

/// The Settings window (Command-Comma). One tab per topic, at most about
/// six. Each tab is a grouped Form that sizes to its content, so the
/// window grows to fit and shows no scroll bar it does not need.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.settingsTab) {
            ForEach(SettingsTab.allCases) { tab in
                page(tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
        .noInitialFocus()
    }

    @ViewBuilder
    private func page(_ tab: SettingsTab) -> some View {
        Form {
            switch tab {
            case .general: GeneralSettings()
            case .automation: AutomationSettings()
            case .notifications: NotificationSettings()
            case .appearance: AppearanceSettings()
            }
        }
        .formStyle(.grouped)
        .fitsContent()
        .frame(width: 520)
    }
}

/// The Settings tabs. Snapshot mode walks through every case.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, automation, notifications, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .automation: "Automation"
        case .notifications: "Notifications"
        case .appearance: "Appearance"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .automation: "wand.and.sparkles"
        case .notifications: "bell.badge"
        case .appearance: "paintpalette"
        }
    }
}

struct GeneralSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        @Bindable var monitor = model.monitor
        Section {
            Picker("Refresh interval", selection: $monitor.refreshInterval) {
                ForEach(MemoryMonitor.refreshChoices, id: \.self) { seconds in
                    Text(seconds == 1 ? "1 second" : "\(seconds) seconds").tag(seconds)
                }
            }
        } footer: {
            if monitor.refreshInterval < 2 {
                Text("Faster refresh uses more energy.")
                    .foregroundStyle(.secondary)
            }
        }
        Section {
            Picker("Menu bar shows", selection: $model.menuBarText) {
                ForEach(MenuBarText.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Text size", selection: $model.largeMenuBarText) {
                Text("Regular").tag(false)
                Text("Large").tag(true)
            }
            .disabled(model.menuBarText == .iconOnly)
            Toggle("Open at login", isOn: $model.openAtLogin)
        }
        Section {
            LabeledContent("Memory window shortcut") {
                ShortcutRecorder(shortcut: $model.shortcut) { model.pauseShortcut($0) }
            }
        } footer: {
            if model.shortcutTaken, let shortcut = model.shortcut {
                Text("Another app uses \(shortcut.display). Record a different shortcut.")
                    .foregroundStyle(.red)
            } else {
                Text("Opens and closes the memory window from any app.")
                    .foregroundStyle(.secondary)
            }
        }
        ICloudSyncSection()
        Section {
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
        }
    }
}

/// Settings › General › iCloud: the same settings on every Mac.
struct ICloudSyncSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var sync = model.settingsSync
        Section {
            Toggle("Sync settings with iCloud", isOn: $sync.enabled)
                .disabled(!sync.available)
        } footer: {
            Group {
                if !sync.available {
                    Text("Turn on iCloud Drive in System Settings › Apple Account › iCloud to sync.")
                } else if sync.enabled, let last = sync.lastSync {
                    Text("Synced \(Text(last.date, style: .relative)) ago with \(last.device). Saved in iCloud Drive › MangoCleaner.")
                } else {
                    Text("Keeps these settings the same on every Mac signed in to your iCloud account. Each Mac still asks once for the helper.")
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}
