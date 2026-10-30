import AppKit
import MangoMemoryKit

/// Quits other apps. Test runs use `FakeQuitter`, so they never quit a real app.
protocol AppQuitter {
    /// Asks the app to quit normally; it can save first.
    func quit(_ pid: Int32) -> Bool
    /// Closes the app at once; unsaved work is lost.
    func forceQuit(_ pid: Int32) -> Bool
    func isRunning(_ pid: Int32) -> Bool
}

struct SystemQuitter: AppQuitter {
    func quit(_ pid: Int32) -> Bool {
        NSRunningApplication(processIdentifier: pid)?.terminate() ?? false
    }

    func forceQuit(_ pid: Int32) -> Bool {
        NSRunningApplication(processIdentifier: pid)?.forceTerminate() ?? false
    }

    func isRunning(_ pid: Int32) -> Bool {
        NSRunningApplication(processIdentifier: pid).map { !$0.isTerminated } ?? false
    }
}

/// Records what it was asked to do. Apps "exit" only when `obeys` is true.
final class FakeQuitter: AppQuitter {
    var obeys = true
    private(set) var quitRequests: [Int32] = []
    private(set) var forceQuitRequests: [Int32] = []
    private var exited: Set<Int32> = []

    func quit(_ pid: Int32) -> Bool {
        quitRequests.append(pid)
        if obeys { exited.insert(pid) }
        return true
    }

    func forceQuit(_ pid: Int32) -> Bool {
        forceQuitRequests.append(pid)
        exited.insert(pid)
        return true
    }

    func isRunning(_ pid: Int32) -> Bool { !exited.contains(pid) }
}

/// Where each app in Top Apps is in the Quit flow (S-006, S-007).
enum QuitState: Equatable {
    case quitting
    /// Still running after `QuitFlow.patience`: offer Force Quit.
    case refused
}

/// Quit, then offer Force Quit when the app ignores Quit.
@Observable
final class QuitFlow {
    /// How long an app gets to quit before Force Quit is offered.
    var patience: Duration = .seconds(5)
    private(set) var states: [Int32: QuitState] = [:]
    private let quitter: any AppQuitter

    init(quitter: any AppQuitter) {
        self.quitter = quitter
    }

    func quit(_ app: AppUsage) {
        guard states[app.pid] == nil, quitter.quit(app.pid) else { return }
        states[app.pid] = .quitting
        Task {
            try? await Task.sleep(for: patience)
            guard states[app.pid] == .quitting else { return }
            states[app.pid] = quitter.isRunning(app.pid) ? .refused : nil
        }
    }

    func forceQuit(_ app: AppUsage) {
        if quitter.forceQuit(app.pid) { states[app.pid] = nil }
    }

    /// Forgets apps that are no longer in Top Apps (they quit).
    func prune(keeping apps: [AppUsage]) {
        let pids = Set(apps.map(\.pid))
        states = states.filter { pids.contains($0.key) }
    }

    /// Snapshot mode shows a state without quitting anything.
    func show(_ state: QuitState?, for pid: Int32) {
        states[pid] = state
    }
}
