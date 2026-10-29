import Testing
@testable import MangoCleanerKit

@Test("Memory sizes read like Activity Monitor", arguments: [
    (UInt64(0), "0 MB"),
    (UInt64(536_870_912), "512 MB"),
    (UInt64(1_073_741_824), "1.0 GB"),
    (UInt64(3_650_722_201), "3.4 GB"),
    (UInt64(25_769_803_776), "24.0 GB"),
])
func formats(_ bytes: UInt64, expected: String) {
    #expect(ByteText.string(bytes) == expected)
}
