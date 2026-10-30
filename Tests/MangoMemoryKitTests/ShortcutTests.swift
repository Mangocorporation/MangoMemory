import Foundation
import Testing
@testable import MangoMemoryKit

@Test("The default shortcut is Control-Option-M")
func standardShortcut() {
    #expect(Shortcut.standard.display == "⌃⌥M")
    #expect(Shortcut.standard.isValid)
    #expect(Shortcut.standard.carbonModifiers == 0x1800)
}

@Test("Modifiers show in Apple's order")
func modifierOrder() {
    let shortcut = Shortcut(keyCode: 0, modifiers: [.command, .shift, .option, .control], key: "a")
    #expect(shortcut.display == "⌃⌥⇧⌘A")
}

@Test("Shift alone or no modifier is not a global shortcut")
func needsModifier() {
    #expect(!Shortcut(keyCode: 46, modifiers: [], key: "M").isValid)
    #expect(!Shortcut(keyCode: 46, modifiers: [.shift], key: "M").isValid)
    #expect(Shortcut(keyCode: 46, modifiers: [.command, .shift], key: "M").isValid)
}

@Test("A shortcut survives saving")
func shortcutCodable() throws {
    let data = try JSONEncoder().encode(Shortcut.standard)
    #expect(try JSONDecoder().decode(Shortcut.self, from: data) == .standard)
}
