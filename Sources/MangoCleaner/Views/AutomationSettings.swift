import MangoCleanerKit
import SwiftUI

/// Settings > Automation (S-014 to S-016): Clear automatically.
struct AutomationSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var auto = model.autoClear
        Section {
            Toggle("Clear automatically when pressure stays high", isOn: $auto.whenPressureHigh)
            Picker("Pressure high for", selection: $auto.highFor) {
                ForEach(AutoClearRules.durations, id: \.self) { seconds in
                    Text(seconds < 60 ? "\(Int(seconds)) seconds" : seconds == 60 ? "1 minute" : "\(Int(seconds / 60)) minutes")
                        .tag(seconds)
                }
            }
            .disabled(!auto.whenPressureHigh)
        }
        Section {
            Toggle("Clear automatically after a big app quits", isOn: $auto.afterBigQuit)
            Picker("Big app uses more than", selection: $auto.bigApp) {
                ForEach(AutoClearRules.thresholds, id: \.self) { bytes in
                    Text(ByteText.string(bytes).replacingOccurrences(of: ".0 ", with: " ")).tag(bytes)
                }
            }
            .disabled(!auto.afterBigQuit)
        } footer: {
            AutomationStatus()
        }
    }
}

/// When the file cache was last cleared automatically, when it can be again,
/// and whether the helper is ready.
private struct AutomationStatus: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let auto = model.autoClear
        let flow = model.cleanFlow
        let on = auto.whenPressureHigh || auto.afterBigQuit
        VStack(alignment: .leading, spacing: Space.sm) {
            if on && flow.helperStatus != .ready {
                HStack(spacing: Space.sm) {
                    Text(flow.helperStatus == .needsApproval
                         ? "Turn on MangoCleaner in System Settings › Login Items to clear automatically."
                         : "Clearing the file cache needs a small helper with administrator rights.")
                    Button(flow.helperStatus == .needsApproval ? "Open Login Items" : "Allow Helper…") {
                        flow.helperStatus == .needsApproval ? flow.openLoginItems() : flow.allowHelper()
                    }
                }
            }
            // Ticks once a second only while Settings shows this tab.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let line = AutoClearText.status(last: auto.lastResult,
                                                   nextPossible: on ? auto.rules.nextPossible(at: context.date) : nil,
                                                   now: context.date) {
                    Text(line)
                }
            }
        }
        .foregroundStyle(.secondary)
        .onAppear { flow.refreshStatus() }
    }
}

/// Settings > Notifications (S-017).
struct NotificationSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var alerts = model.alerts
        Section {
            Toggle("Notify when pressure is Critical", isOn: $alerts.whenCritical)
            Toggle("Notify when pressure is High", isOn: $alerts.whenHigh)
        } footer: {
            Text("One notification when pressure rises, then none for 30 minutes. It names the app using the most memory.")
                .foregroundStyle(.secondary)
        }
    }
}
