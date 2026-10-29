# MangoCleaner

A native macOS menu bar app in SwiftUI (`MenuBarExtra`, window style,
`LSUIElement`). It shows memory pressure, the top apps by memory, and clears
the file cache. No database and no server: settings live in UserDefaults
(`Store.defaults`). The plan is in `docs/BRIEF.md`, the backlog in
`docs/STORIES.md`, and the names in `docs/GLOSSARY.md`: use only glossary words in the UI.

## Layout

- `Sources/MangoCleaner/` the app. `App.swift` has the menu bar extra, Settings, and `Store` (which defaults to use). `ContentView.swift` has the menu bar label and the memory window.
- `Sources/MangoCleanerKit/` rules and data logic with no SwiftUI. Tests in `Tests/MangoCleanerKitTests/`.
- `Package.swift` a Swift package. There is no Xcode project.
- `build.sh` builds, signs, and installs `~/Applications/MangoCleaner.app`.
- `Icon/AppIcon.icon` the app icon, an Icon Composer file (JSON plus SVG layers). `build.sh` compiles it with `tools/make_icon.sh`; `tools/icon_review.sh` renders every look into one PNG.
- `docs/` the brief, the screen index, and the user stories, when they exist.

## Build and check

- Build and install: `./build.sh`. Add `--open` to restart the app with the new build. The build shows warnings; fix them.
- Unit tests: `swift test --scratch-path ~/Library/Developer/MangoCleaner/test-build`.
- Self-test (the app's real functions on test settings): `tools/selftest.sh`. Exit 0 when every check passes. Add a check for every story with logic in `SelfTest.swift`.
- After every UI change, take snapshots with sample data and look at them: `tools/snap.sh`.
  It writes `/tmp/MangoCleaner-shots/<page>-light.png` and `-dark.png` for every page in `Snapshot.pages` (the memory window, opened by clicking the app's own menu bar item), and `settings-<tab>-light.png` and `-dark.png` for every Settings tab, then quits. `APP_SNAPSHOT_PAGES=window,settings tools/snap.sh` limits the pages.
  For a new window state, popover, or alert named in a story, add a page to `Snapshot.pages` and set the state before the capture.
- Snapshots and the self-test refuse to run without `APP_STORE`; they then use the `com.mangocorp.mangocleaner.test` defaults suite, never the real settings.
- Never quit, force quit, or clear the cache for real in a test run: inject fakes for app lists and the helper.
- Then check the grid: `tools/grid-lint.sh` and `swift tools/check-layout.swift /tmp/MangoCleaner-shots/*-layout.json`. Both print PASS.
- A change is done when the build has no errors, the grid checks pass, and you looked at the light and dark snapshots.

## Design rules

Design rules: `design/DESIGN-SYSTEM.md`. Use its tokens; never raw colors, radii, or durations.

- Use Apple's controls and system styles. Only the accent color is custom: `UI/Theme.swift` (`ThemeStore.defaultID`). People change it, and light or dark mode, in Settings > Appearance.
- Views use `.tint`, `Palette.accent`, `Palette.accentText` (accent-colored text), and `Palette.onAccent` (text on an accent fill). Never hard-code colors, radii, or durations in views.
- Compare accents: add `APP_ACCENT=<id>` to the snapshot command.
- Spacing comes from `Space` in `UI/Grid.swift`, on a 4 pt grid. Mark custom pages and cards with `.gridArea` and `.gridProbe`.
- Windows open calm: `.noInitialFocus()` on every window and sheet (no focus ring or selected text on open), `.fitsContent()` on sheets and Settings tabs (no scroll bar with nothing to scroll). System scroll bars. Both in `UI/WindowBehavior.swift`.
- Settings: one tab per topic in `SettingsView.swift`, one grouped Form per tab. Add a case to `SettingsTab` for a new tab.
- Window chrome (menu bar window, Settings, menus, alerts) stays system. Buttons use system styles, like `.borderedProminent`.
- Colors: `.primary`, `.secondary`, `.tint`, and system colors. Never fixed grays or white for text.
- Every action is in the gear menu or the row's context menu, and has a keyboard shortcut. There is no main menu bar (agent app).
- `Label` for icon and text pairs. SF Symbols for icons.
- `ContentUnavailableView` for empty states.
- Liquid Glass belongs to floating controls only, never to content.

## Skills

The bama plugin has a skill for each step: `mac-design` (design rules),
`design-system` (accent and tokens), `layout-grid`, `ux-design`,
`swift-swiftui`, `os-integrations`, `performance`, `build-and-verify`,
`test-mac-app`, `app-icon`, `user-stories`, and `improve-loop`. Use them.

## Git

- Commit after each working change, with a message that says what the user can now do.
