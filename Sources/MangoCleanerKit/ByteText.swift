import Foundation

/// How MangoCleaner writes memory sizes: "3.4 GB", "512 MB". Binary units
/// (1 GB = 1024³ bytes), like Activity Monitor. Logic lives in this library
/// so tests run without the app.
public enum ByteText {
    private static let mb: Double = 1_048_576
    private static let gb: Double = 1_073_741_824

    /// GB with one decimal from 1 GB up, whole MB below.
    public static func string(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if value >= gb {
            return String(format: "%.1f GB", value / gb)
        }
        return String(format: "%.0f MB", value / mb)
    }
}
