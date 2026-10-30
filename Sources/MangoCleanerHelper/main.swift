import Foundation
import MangoCleanerKit

// MangoCleanerHelper: a launchd daemon (SMAppService.daemon) that runs as root
// and does one thing, run /usr/sbin/purge, for MangoCleaner signed by our team.
// Plist: Helper/com.mangocorp.mangocleaner.helper.plist, embedded by build.sh.

final class HelperService: NSObject, HelperProtocol {
    func clearFileCache(reply: @escaping @Sendable (Int32) -> Void) {
        let purge = Process()
        purge.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        do {
            try purge.run()
            purge.waitUntilExit()
            reply(purge.terminationStatus)
        } catch {
            reply(-1)
        }
    }
}

final class Listener: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Refuses every caller that is not MangoCleaner signed by our team.
        connection.setCodeSigningRequirement(Helper.clientRequirement)
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = HelperService()
        connection.resume()
        return true
    }
}

let delegate = Listener()
let listener = NSXPCListener(machServiceName: Helper.machService)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
