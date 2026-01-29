// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Hash_Table_Primitives_Core
public import Ordinal_Primitives

extension Hash.Table where Element: ~Copyable {
    /// Updates positions after an element is removed from external storage.
    ///
    /// When an element at `removedPosition` is removed from external storage,
    /// all positions greater than `removedPosition` must be decremented.
    ///
    /// - Parameter removedPosition: The typed position that was removed.
    @inlinable
    public mutating func decrementPositions(after removedPosition: Index<Element>) {
        let removedRaw = Int(bitPattern: removedPosition.position.rawValue)
        let cap = Int(_storage.header.capacity.rawValue.rawValue)

        for i in 0..<cap {
            let bucketIdx = BucketIndex(__unchecked: (), Ordinal(UInt(i)))
            let hash = _storage.readHash(at: bucketIdx)
            if hash != Self.empty && hash != Self.deleted {
                let pos = _storage.readPosition(at: bucketIdx)
                let posRaw = Int(bitPattern: pos.position.rawValue)
                if posRaw > removedRaw {
                    let newPos = Index<Element>(__unchecked: (), Ordinal(UInt(posRaw - 1)))
                    _storage.writePosition(at: bucketIdx, value: newPos)
                }
            }
        }
    }
}
