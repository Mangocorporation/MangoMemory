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
    case general, automation, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .automation: "Automation"
        case .appearance: "Appearance"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .automation: "wand.and.sparkles"
        case .appearance: "paintpalette"
        }
    }
}

struct GeneralSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
        }
    }
}
