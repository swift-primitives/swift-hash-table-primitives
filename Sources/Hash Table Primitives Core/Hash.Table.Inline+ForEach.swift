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

extension Hash.Table.Inline where Element: ~Copyable {
    /// Iterates over all occupied buckets (non-empty, non-deleted).
    ///
    /// - Parameter body: A closure called with the bucket index, stored hash value,
    ///   and element position for each occupied bucket.
    ///
    /// - Complexity: O(n) where n is bucket capacity.
    @inlinable
    public borrowing func forEachOccupied(
        _ body: (_ bucket: Int, _ hash: Int, _ position: Index<Element>) -> Void
    ) {
        for i in 0..<bucketCapacity {
            let hash = _hashes[i]
            if hash != Self.empty && hash != Self.deleted {
                let position = Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: _positions[i])))
                body(i, hash, position)
            }
        }
    }

    /// Iterates over all positions in the hash table.
    ///
    /// A simpler variant that only provides positions, not bucket indices or hashes.
    ///
    /// - Parameter body: A closure called with each element position.
    ///
    /// - Complexity: O(n) where n is bucket capacity.
    @inlinable
    public borrowing func forEachPosition(_ body: (Index<Element>) -> Void) {
        for i in 0..<bucketCapacity {
            let hash = _hashes[i]
            if hash != Self.empty && hash != Self.deleted {
                let position = Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: _positions[i])))
                body(position)
            }
        }
    }

    /// Iterates over all occupied buckets with early exit support.
    ///
    /// - Parameter body: A closure called with bucket index, hash, and position.
    ///   Return `true` to continue iteration, `false` to stop.
    /// - Returns: `true` if iteration completed, `false` if stopped early.
    ///
    /// - Complexity: O(n) where n is bucket capacity.
    @inlinable
    @discardableResult
    public borrowing func forEachOccupiedWhile(
        _ body: (_ bucket: Int, _ hash: Int, _ position: Index<Element>) -> Bool
    ) -> Bool {
        for i in 0..<bucketCapacity {
            let hash = _hashes[i]
            if hash != Self.empty && hash != Self.deleted {
                let position = Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: _positions[i])))
                if !body(i, hash, position) {
                    return false
                }
            }
        }
        return true
    }
}
