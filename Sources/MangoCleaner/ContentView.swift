import SwiftUI

/// The menu bar item. It is drawn at launch, so it also starts the
/// self-test and snapshot runs, which need SwiftUI's openSettings.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(systemName: "memorychip")
            .accessibilityLabel("MangoCleaner")
            .task {
                SelfTest.runIfRequested(model: model)
                Snapshot.runIfRequested(model: model, openSettings: openSettings)
            }
    }
}

/// The window that drops down from the menu bar item. Its sections arrive
/// story by story (docs/STORIES.md, M1).
struct MemoryWindow: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Memory Pressure")
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Settings…") { openSettings() }
                        .keyboardShortcut(",")
                    Divider()
                    Button("Quit MangoCleaner") { NSApp.terminate(nil) }
                        .keyboardShortcut("q")
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Show settings and more")
                .accessibilityLabel("More")
            }
            .gridProbe("header", area: "window")
            Text("Memory details appear here.")
                .foregroundStyle(.secondary)
                .gridProbe("placeholder", area: "window")
        }
        .padding(Space.margin)
        .gridArea("window")
        .frame(width: 320)
    }
}
