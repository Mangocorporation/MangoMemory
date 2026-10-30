import Foundation
import MangoCleanerKit
import ServiceManagement

/// Whether the helper can clear the file cache (S-010).
enum HelperStatus: Equatable {
    /// Not registered yet: the window offers Allow Helper….
    case notRegistered
    /// Registered, waiting for the person to turn it on in Login Items.
    case needsApproval
    case ready
}

enum ClearError: Error, Equatable {
    case helperUnavailable
    case purgeFailed(Int32)
}

/// Clears the file cache. Test runs use `FakeCacheClearer`: they never run purge.
protocol CacheClearer {
    var status: HelperStatus { get }
    func register() throws
    func openLoginItems()
    func clear() async throws
}

/// The real helper: an SMAppService daemon reached over XPC.
struct HelperCacheClearer: CacheClearer {
    private var service: SMAppService { .daemon(plistName: Helper.plistName) }

    var status: HelperStatus {
        switch service.status {
        case .enabled: .ready
        case .requiresApproval: .needsApproval
        default: .notRegistered
        }
    }

    func register() throws {
        try service.register()
    }

    func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func clear() async throws {
        let code: Int32 = try await withCheckedThrowingContinuation { continuation in
            let connection = NSXPCConnection(machServiceName: Helper.machService, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
            let call = XPCCall(continuation, connection: connection)
            connection.invalidationHandler = { call.finish(.failure(ClearError.helperUnavailable)) }
            connection.resume()
            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
                call.finish(.failure(ClearError.helperUnavailable))
            } as? HelperProtocol
            guard let proxy else {
                call.finish(.failure(ClearError.helperUnavailable))
                return
            }
            proxy.clearFileCache { code in call.finish(.success(code)) }
        }
        if code != 0 { throw ClearError.purgeFailed(code) }
    }
}

/// XPC can call the reply, the error handler, and the invalidation handler, on its
/// own queue. Resumes the continuation once, then closes the connection.
nonisolated private final class XPCCall: @unchecked Sendable {
    private var continuation: CheckedContinuation<Int32, Error>?
    private let connection: NSXPCConnection
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<Int32, Error>, connection: NSXPCConnection) {
        self.continuation = continuation
        self.connection = connection
    }

    func finish(_ result: Result<Int32, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return }
        pending.resume(with: result)
        connection.invalidate()
    }
}

/// For test runs: pretends, records, never runs purge.
final class FakeCacheClearer: CacheClearer {
    var status: HelperStatus = .ready
    var fails = false
    private(set) var clears = 0

    func register() throws { status = .needsApproval }
    func openLoginItems() {}

    func clear() async throws {
        try? await Task.sleep(for: .milliseconds(100))
        if fails { throw ClearError.helperUnavailable }
        clears += 1
    }
}

/// Clear File Cache with its before and after (S-011, S-012).
@Observable
final class CleanFlow {
    enum State: Equatable {
        case idle
        case clearing
        case done(CleanResult)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var helperStatus: HelperStatus
    /// How long the result line stays.
    var resultDuration: Duration = .seconds(10)
    /// Called after every clear that finished, whatever started it.
    var onCleared: ((CleanResult) -> Void)?

    private let clearer: any CacheClearer
    private let measure: () async -> MemoryStats?
    private var hide: Task<Void, Never>?

    init(clearer: any CacheClearer, measure: @escaping () async -> MemoryStats?) {
        self.clearer = clearer
        self.measure = measure
        helperStatus = clearer.status
    }

    var isClearing: Bool { state == .clearing }

    /// Reads the helper's status again (it changes in System Settings).
    func refreshStatus() {
        helperStatus = clearer.status
    }

    func allowHelper() {
        do {
            try clearer.register()
        } catch {
            state = .failed("Unable to add the helper. \(error.localizedDescription)")
        }
        refreshStatus()
        if helperStatus == .needsApproval { clearer.openLoginItems() }
    }

    func openLoginItems() { clearer.openLoginItems() }

    func clear(trigger: CleanTrigger) async {
        refreshStatus()
        guard helperStatus == .ready, !isClearing else { return }
        hide?.cancel()
        state = .clearing
        let before = await measure()
        do {
            try await clearer.clear()
            // The file cache shrinks over a moment; measure after it settles.
            try? await Task.sleep(for: .seconds(1))
            if let before, let after = await measure() {
                let result = CleanResult(date: .now, trigger: trigger, before: before, after: after)
                show(.done(result))
                onCleared?(result)
            } else {
                show(.idle)
            }
        } catch ClearError.purgeFailed(let code) {
            show(.failed("Unable to clear the file cache (purge exited with \(code))."))
        } catch {
            refreshStatus()
            show(.failed("Unable to clear the file cache. The helper didn't respond."))
        }
    }

    /// Snapshot mode shows a state without clearing anything.
    func show(_ state: State, helper: HelperStatus) {
        hide?.cancel()
        self.state = state
        // Set the fake too, so reading the status again keeps the staged one.
        (clearer as? FakeCacheClearer)?.status = helper
        helperStatus = helper
    }

    private func show(_ new: State) {
        state = new
        guard new != .idle else { return }
        hide = Task {
            try? await Task.sleep(for: resultDuration)
            if !Task.isCancelled { state = .idle }
        }
    }
}
