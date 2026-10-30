import Foundation
import Testing
@testable import MangoMemoryKit

private let values = SyncedSettings.Values(
    refreshInterval: 2, menuBarText: "available", largeMenuBarText: false, openAtLogin: false,
    shortcut: .standard, clearWhenPressureHigh: false, highFor: 60, clearAfterBigQuit: false,
    bigApp: 2_147_483_648, notifyCritical: true, notifyHigh: false, accent: "system")
private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

@Test("A newer file from another Mac replaces this Mac's settings")
func newerWins() {
    var other = values
    other.menuBarText = "pressure"
    let file = SyncedSettings(values: other, modified: now + 10, device: "Other Mac")
    #expect(file.replaces(values, changedAt: now))
    #expect(file.replaces(values, changedAt: nil))
}

@Test("An older or identical file changes nothing")
func olderLoses() {
    var other = values
    other.notifyHigh = true
    #expect(!SyncedSettings(values: other, modified: now - 10, device: "Other Mac").replaces(values, changedAt: now))
    #expect(!SyncedSettings(values: values, modified: now + 10, device: "Other Mac").replaces(values, changedAt: now))
}

@Test("The file survives a round trip, shortcut and date included")
func roundTrip() throws {
    let file = SyncedSettings(values: values, modified: Date(timeIntervalSince1970: 1_800_000_000), device: "Mac")
    #expect(try SyncedSettings.decode(file.encoded()) == file)
}
