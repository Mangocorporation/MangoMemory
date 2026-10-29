import SwiftUI

/// Settings > Appearance: the accent color. Light and dark mode follow the Mac.
struct AppearanceSettings: View {
    @Bindable private var store = ThemeStore.shared

    var body: some View {
        Section {
            AccentPreview()
                .padding(.vertical, Space.xs)
            LabeledContent("Accent color") {
                VStack(alignment: .trailing, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        ForEach(Theme.all) { theme in
                            AccentSwatch(theme: theme, selected: store.themeID == theme.id) {
                                store.themeID = theme.id
                            }
                        }
                    }
                    Text(store.theme.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A small sample of the memory window in the chosen accent: a selected row,
/// accent text, a button, and a switch. It redraws as people pick a color.
private struct AccentPreview: View {
    private let shape = RoundedRectangle(cornerRadius: Radius.md, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Top Apps").font(.headline)
                Spacer()
                Text("3.4 GB free").font(.caption).foregroundStyle(Palette.accentText)
            }
            row("Safari", size: "6.1 GB", symbol: "safari", selected: true)
            row("Mail", size: "820 MB", symbol: "envelope", selected: false)
            Spacer(minLength: 0)
            // Drawn, not real controls: the preview is a picture, and real
            // controls turn gray when the window is not in front.
            HStack {
                Label("Clear File Cache", systemImage: "sparkles")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, Space.md)
                    .frame(height: 24)
                    .background(Palette.accent, in: Capsule())
                Spacer()
                Text("Clear automatically").font(.caption).foregroundStyle(.secondary)
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: 28, height: 16)
                    .overlay(alignment: .trailing) {
                        Circle().fill(.white).padding(2).shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                    }
            }
        }
        .padding(Space.md)
        .frame(height: 152)
        .background(.background, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.separator, lineWidth: 1))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the accent color")
    }

    private func row(_ name: String, size: String, symbol: String, selected: Bool) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: symbol)
            Text(name)
            Spacer()
            Text(size).monospacedDigit()
        }
        .font(.callout)
        .foregroundStyle(selected ? Palette.onAccent : .primary)
        .padding(.horizontal, Space.sm)
        .frame(height: 24)
        .background(selected ? Palette.accent : .clear,
                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }
}

/// One color dot, like the accent row in System Settings.
private struct AccentSwatch: View {
    let theme: Theme
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            Circle()
                .fill(fill)
                .frame(width: 16, height: 16)
                .overlay {
                    if selected {
                        Circle().fill(theme.onAccent).frame(width: 6, height: 6) // grid: ok
                    }
                }
                .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(theme.name)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fill: AnyShapeStyle {
        if let tint = theme.tint {
            AnyShapeStyle(tint)
        } else {
            AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                          center: .center))
        }
    }
}
