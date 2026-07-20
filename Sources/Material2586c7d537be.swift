import CryptoKit
import Foundation

enum EncodedMaterialdc13d721b1dc {
    static let pieces: [[UInt8]] = [[129, 195, 142, 126, 60, 6, 133, 7, 243, 23, 131, 129, 249, 113, 137, 118, 49, 86, 16, 209], [151, 67, 42, 113, 138, 109, 151], [46, 216, 178, 85, 9]]
    static let layout: [Int] = [2, 1, 0]

    static func key() -> SymmetricKey {
        let ordered = zip(layout, pieces).sorted { $0.0 < $1.0 }
        var bytes = ordered.flatMap { $0.1 }
        for index in bytes.indices { bytes[index] = bytes[index] &- 245 }
        for index in bytes.indices { bytes[index] = (bytes[index] >> 4) | (bytes[index] << 4) }
        for index in bytes.indices { bytes[index] = bytes[index] ^ 164 }
        return SymmetricKey(data: Data(bytes))
    }
}
