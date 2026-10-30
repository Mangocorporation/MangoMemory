import MangoMemoryKit
import SwiftUI

/// The bottom of the memory window: Clear File Cache, or what the helper still needs (S-010 to S-012).
struct CleanSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let flow = model.cleanFlow
        VStack(alignment: .leading, spacing: Space.sm) {
            switch flow.helperStatus {
            case .ready:
                Button {
                    Task { await flow.clear(trigger: .button) }
                } label: {
                    HStack(spacing: Space.sm) {
                        if flow.isClearing { ProgressView().controlSize(.small) }
                        Text(flow.isClearing ? "Clearing File Cache…" : "Clear File Cache")
                    }
                    .foregroundStyle(Palette.onAccent)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(flow.isClearing)
                .help("Empty the file cache now (⌘K). macOS refills it as you open files.")
            case .notRegistered:
                Text("Clearing the file cache needs a small helper with admin rights. macOS asks you once.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { flow.allowHelper() } label: {
                    Text("Allow Helper…").foregroundStyle(Palette.onAccent)
                }
                .buttonStyle(.borderedProminent)
                .help("Add the helper; macOS asks you to turn it on in Login Items")
            case .needsApproval:
                Text("Turn on MangoMemory in System Settings › Login Items to finish.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { flow.openLoginItems() } label: {
                    Text("Open Login Items").foregroundStyle(Palette.onAccent)
                }
                .buttonStyle(.borderedProminent)
                .help("Open System Settings › Login Items")
            }
            result(flow.state)
        }
        .animation(Motion.ui, value: flow.state)
    }

    @ViewBuilder
    private func result(_ state: CleanFlow.State) -> some View {
        switch state {
        case .done(let result):
            Label(result.summary, systemImage: result.freed >= CleanResult.noticeable ? "checkmark.circle" : "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(StatusColor.critical)
                .fixedSize(horizontal: false, vertical: true)
        case .idle, .clearing:
            EmptyView()
        }
    }
}
