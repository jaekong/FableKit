import SwiftUI

extension AnyView: @retroactive Identifiable {
    nonisolated var stableHash: UInt64 {
        var copy = copy self
        let bytes = withUnsafeBytes(of: &copy, Array.init)
        return bytes.reduce(UInt64(5381)) { 127 * ($0 & 0x00ffffffffffffff) + UInt64($1) }
    }
    
    nonisolated public var id: UUID {
        let stableHash = self.stableHash
        var uuidValue: UInt128 = UInt128(stableHash) << 64 + UInt128(stableHash)
        let bytes = withUnsafeBytes(of: &uuidValue, Array.init)
        return UUID(uuid: bytes.uuid)
    }
}
