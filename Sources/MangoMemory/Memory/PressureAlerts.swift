import Foundation
import MangoMemoryKit
import UserNotifications

/// Posts notifications. Test runs use `FakeNotifier`: they never post.
protocol Notifier {
    /// `quit` adds a "Quit <name>" button to the notification.
    func post(title: String, body: String, quit: AppUsage?)
}

/// The real notifications. Asks for permission the first time it posts.
final class SystemNotifier: NSObject, Notifier, UNUserNotificationCenterDelegate {
    /// Called when someone clicks Quit <name> on a notification.
    var onQuit: ((AppUsage) -> Void)?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func post(title: String, body: String, quit: AppUsage?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let quit {
            // One category per alert: its button names the app.
            let action = UNNotificationAction(identifier: "quit", title: "Quit \(quit.name)")
            UNUserNotificationCenter.current().setNotificationCategories(
                [UNNotificationCategory(identifier: "pressure", actions: [action], intentIdentifiers: [])])
            content.categoryIdentifier = "pressure"
            content.userInfo = ["pid": Int(quit.pid), "name": quit.name]
        }
        let request = UNNotificationRequest(identifier: "pressure", content: content, trigger: nil)
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            try? await center.add(request)
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard response.actionIdentifier == "quit", let pid = info["pid"] as? Int, let name = info["name"] as? String
        else { return }
        await MainActor.run {
            onQuit?(AppUsage(pid: Int32(pid), name: name, bundlePath: nil, bytes: 0))
        }
    }

    /// Shows the banner even when MangoMemory's window is in front.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// For test runs: records, never posts.
final class FakeNotifier: Notifier {
    private(set) var posted: [(title: String, body: String, quit: AppUsage?)] = []

    func post(title: String, body: String, quit: AppUsage?) {
        posted.append((title, body, quit))
    }
}

/// A quiet notification when pressure turns Critical, or High if chosen (S-017).
@Observable
final class PressureAlerts {
    private(set) var rules = PressureAlertRules()

    var whenCritical: Bool {
        get { rules.whenCritical }
        set { rules.whenCritical = newValue; Store.defaults.set(newValue, forKey: "notify.critical") }
    }
    var whenHigh: Bool {
        get { rules.whenHigh }
        set { rules.whenHigh = newValue; Store.defaults.set(newValue, forKey: "notify.high") }
    }

    private let notifier: any Notifier
    private let topApp: () async -> AppUsage?

    init(notifier: any Notifier, topApp: @escaping () async -> AppUsage?) {
        self.notifier = notifier
        self.topApp = topApp
        rules.whenCritical = Store.defaults.object(forKey: "notify.critical") as? Bool ?? true
        rules.whenHigh = Store.defaults.bool(forKey: "notify.high")
    }

    /// Every pressure reading comes here. Returns the post it started, if any.
    @discardableResult
    func reading(_ level: PressureLevel, at now: Date = .now) -> Task<Void, Never>? {
        guard let level = rules.reading(level, at: now) else { return nil }
        return Task {
            let top = await topApp()
            notifier.post(title: PressureAlertText.title(level), body: PressureAlertText.body(top: top), quit: top)
        }
    }
}
