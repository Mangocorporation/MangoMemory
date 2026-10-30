import AppKit
import MangoCleanerKit
import SwiftUI

/// The window that drops down from the menu bar item (S-003): pressure,
/// the breakdown, and Top Apps.
struct MemoryWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    /// The window takes the keys as soon as it opens (S-019): nothing else has focus.
    @FocusState private var takesKeys: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            PressureHeader(stats: model.monitor.windowStats)
                .gridProbe("header", area: "window")
            if let stats = model.monitor.windowStats {
                MemoryBreakdown(stats: stats)
                    .gridProbe("breakdown", area: "window")
            }
            TopAppsList()
                .gridProbe("top-apps", area: "window")
                // The divider sits in the gap, so sections stay on the 4 pt grid.
                .padding(.top, Space.lg)
                .overlay(alignment: .top) { Divider() }
            CleanSection()
                .gridProbe("clean", area: "window")
        }
        .padding(Space.margin)
        .gridArea("window")
        .frame(width: 320)
        .focusable()
        .focusEffectDisabled()
        .focused($takesKeys)
        .onKeyPress(.downArrow) { model.moveFocus(1); return .handled }
        .onKeyPress(.upArrow) { model.moveFocus(-1); return .handled }
        .onKeyPress(.return) { model.quitFocused(); return .handled }
        .onKeyPress(.escape) { MenuBarItem.button?.performClick(nil); return .handled }
        // The gear menu's shortcuts work only while it is open; these work any time.
        .onKeyPress(keys: ["k", ",", "q"]) { press in
            guard press.modifiers == .command else { return .ignored }
            switch press.key {
            case "k": Task { await model.cleanFlow.clear(trigger: .menu) }
            case ",": openSettings(); NSApp.activate()
            default: NSApp.terminate(nil)
            }
            return .handled
        }
        .onAppear {
            takesKeys = true
            model.monitor.windowIsOpen = true
            model.cleanFlow.refreshStatus()
        }
        .onDisappear { model.monitor.windowIsOpen = false }
    }
}

/// Level word, caption, and the available and percent line, with the gear menu.
struct PressureHeader: View {
    let stats: MemoryStats?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Memory Pressure")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: Space.sm) {
                    Image(systemName: Self.symbol(stats?.level))
                        .foregroundStyle(Self.color(stats?.level))
                    Text(stats?.level.title ?? "Reading…")
                        .contentTransition(.opacity)
                }
                .font(.title.weight(.semibold))
                if let stats {
                    Text("\(ByteText.string(stats.available)) available · \(stats.pressurePercent) % pressure")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .animation(Motion.numberRoll, value: stats.available)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer()
            GearMenu(stats: stats)
        }
    }

    static func symbol(_ level: PressureLevel?) -> String {
        switch level {
        case .normal?: "checkmark.circle.fill"
        case .high?: "exclamationmark.circle.fill"
        case .critical?: "exclamationmark.triangle.fill"
        case nil: "circle.dotted"
        }
    }

    static func color(_ level: PressureLevel?) -> Color {
        switch level {
        case .normal?: StatusColor.normal
        case .high?: StatusColor.high
        case .critical?: StatusColor.critical
        case nil: .secondary
        }
    }
}

/// Settings, live numbers, About, and Quit (S-008).
struct GearMenu: View {
    let stats: MemoryStats?
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Menu {
            Button("Clear File Cache") { Task { await model.cleanFlow.clear(trigger: .menu) } }
                .keyboardShortcut("k")
                .disabled(model.cleanFlow.isClearing || model.cleanFlow.helperStatus != .ready)
            Button("Settings…") { openSettings(); NSApp.activate() }
                .keyboardShortcut(",")
            if let stats {
                Divider()
                ForEach(MemoryPart.allCases) { part in
                    Button("\(part.title)\t\(ByteText.string(part.bytes(in: stats)))") {}
                        .disabled(true)
                }
            }
            Divider()
            Button("About MangoCleaner") {
                NSApp.activate()
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            Button("Quit MangoCleaner") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .tint(Color.secondary)
        .fixedSize()
        .help("Show settings and more")
        .accessibilityLabel("More")
    }
}
