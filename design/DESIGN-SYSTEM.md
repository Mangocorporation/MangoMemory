# MangoCleaner design system

Apple's look (see the `mac-design` skill), plus a few tokens in
`Sources/MangoCleaner/UI/`. Views use tokens, never raw colors, radii, or durations.

## Accent — `Theme.swift`

- `ThemeStore.defaultID` stays `"system"`: the app follows the Mac's accent.
- Brand: Mango (`#FF9F1C`, light `#FFC46B`, deep `#A85A00`), shown only while the
  Mac's accent is Multicolor. People can also pick Mango or any accent in
  Settings > Appearance.
- Use `.tint` or `Palette.accent` for fills, `Palette.accentText` for
  accent-colored text, `Palette.onAccent` for text on an accent fill (dark ink
  for Mango). Never a hex in a view.
- Brand sparingly: the icon, the Clear File Cache button, selection. Never on
  pressure or the memory bar.

## Status — `StatusColors.swift`

- Pressure: `StatusColor.normal` / `.high` / `.critical` (system green, yellow,
  red). Always paired with the level word ("Normal", "High", "Critical") or a
  glyph fill, never color alone.
- Breakdown: `appMemory`, `wired`, `compressed`, `fileCache`, `free`, `swap`.
  The bar segment and its row dot use the same token.
- Status colors are system colors, so they adapt to dark mode and Increase
  Contrast. Never redefine them with hex.

## Spacing — `Grid.swift`

- `Space` on a 4 pt grid: `xs 4`, `sm 8`, `md 12`, `lg 16`, `xl 20`, `xxl 24`,
  `section 32`, `margin 20` (window edge).
- The memory window is 320 pt wide with `Space.margin` padding. Sections are
  `Space.lg` apart, rows inside a section `Space.sm`.
- Mark pages with `.gridArea` and views with `.gridProbe`; `tools/grid-lint.sh`
  and `tools/check-layout.swift` must pass.

## Radius — `Radius.swift`

- `xs 6` the memory bar and chips, `sm 8` controls, `row 10` row hover and
  selection fills, `md 12` cards.
- Inner corners are concentric: inner = outer - inset.

## Motion — `Motion.swift`

- `hover`, `quick`, `ui`, `numberRoll`, `listChange`, `bar`. Each turns into a
  fade or nothing under Reduce Motion.
- Live numbers use `.contentTransition(.numericText())` with `Motion.numberRoll`;
  "GB" and "%" never animate.
- The menu bar item never animates (WindowServer cost, research decision 8).
- Never animate a view's first layout. Hover never moves a selection.

## Rules

- One primary button in the memory window: Clear File Cache.
- Text colors: `.primary`, `.secondary`, `.tint`. Never fixed grays or white.
- Liquid Glass only on floating controls; the window background is the system's.
- Style controls with `ButtonStyle` and `ToggleStyle`; never draw a control from shapes.
