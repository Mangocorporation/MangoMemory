import AppKit
import MangoCleanerKit
import SwiftUI

/// The five apps using the most memory, with Quit and Force Quit (S-005 to S-007).
struct TopAppsList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let apps = model.monitor.topApps
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Top Apps")
                .font(.headline)
            if apps.isEmpty {
                Text(model.monitor.windowStats == nil ? "Reading memory…" : "No apps are open.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(apps) { app in
                        AppRow(app: app,
                               state: model.quitFlow.states[app.pid],
                               focused: model.focusedApp == app.pid,
                               quit: { model.quitFlow.quit(app) },
                               forceQuit: { model.confirming = app })
                            .onHover { inside in
                                if inside { model.focusedApp = app.pid }
                                else if model.focusedApp == app.pid { model.focusedApp = nil }
                            }
                    }
                }
                // Rows pad their hover fill; pull them out so icons line up with the title.
                .padding(.horizontal, -Space.sm)
                .animation(Motion.listChange, value: apps.map(\.pid))
            }
        }
        .onChange(of: apps.map(\.pid)) { _, _ in model.quitFlow.prune(keeping: apps) }
        .confirmationDialog(model.confirming.map(ForceQuitText.title) ?? "",
                            isPresented: Binding(get: { model.confirming != nil }, set: { if !$0 { model.confirming = nil } }),
                            presenting: model.confirming) { app in
            Button("Force Quit", role: .destructive) { model.quitFlow.forceQuit(app) }
            Button("Cancel", role: .cancel) {}
        } message: { app in
            Text(ForceQuitText.message(app))
        }
    }

}

/// The words of the Force Quit confirmation (S-007).
enum ForceQuitText {
    static func title(_ app: AppUsage) -> String { "Force Quit \(app.name)?" }

    static func message(_ app: AppUsage) -> String {
        "\(app.name) isn't responding to Quit. Any unsaved changes in \(app.name) will be lost."
    }
}

struct AppRow: View {
    let app: AppUsage
    let state: QuitState?
    let focused: Bool
    let quit: () -> Void
    let forceQuit: () -> Void

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(nsImage: Self.icon(app))
                .resizable()
                .frame(width: 20, height: 20)
            Text(app.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(app.name)
            Spacer(minLength: Space.sm)
            // Size and button share one slot, so hover never shifts the row.
            ZStack(alignment: .trailing) {
                Text(ByteText.string(app.bytes))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .opacity(showsButton ? 0 : 1)
                action
                    .opacity(showsButton ? 1 : 0)
            }
            .frame(minWidth: 84, alignment: .trailing)
        }
        .font(.callout)
        .padding(.horizontal, Space.sm)
        .frame(height: 28)
        .background(focused ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .opacity(state == .quitting ? 0.5 : 1)
        .animation(Motion.hover, value: focused)
        .animation(Motion.quick, value: state)
        .contextMenu {
            Button("Quit \(app.name)", action: quit)
                .disabled(state != nil)
            Button("Show in Activity Monitor") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(app.name), \(ByteText.string(app.bytes))")
        .accessibilityAction(named: state == .refused ? "Force Quit" : "Quit") {
            state == .refused ? forceQuit() : quit()
        }
    }

    private var showsButton: Bool { focused || state != nil }

    @ViewBuilder
    private var action: some View {
        switch state {
        case .quitting?:
            Text("Quitting…")
                .foregroundStyle(.secondary)
        case .refused?:
            Button("Force Quit", action: forceQuit)
                .controlSize(.small)
                .tint(StatusColor.critical)
                .buttonStyle(.borderedProminent)
                .help("Close \(app.name) at once; unsaved changes are lost")
        case nil:
            Button("Quit", action: quit)
                .controlSize(.small)
                .help("Quit \(app.name) and free \(ByteText.string(app.bytes)) (Return)")
        }
    }

    static func icon(_ app: AppUsage) -> NSImage {
        if let path = app.bundlePath, FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}
