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

extension Hash.Table.Static where Element: ~Copyable {
    /// Iterates over all occupied buckets (non-empty, non-deleted).
    ///
    /// - Parameter body: A closure called with the bucket index and
    ///   bounded element position for each occupied bucket.
    ///
    /// - Complexity: O(n) where n is bucket capacity.
    @inlinable
    package borrowing func eachOccupied(
        _ body: (_ bucket: BucketIndex, _ position: Index<Element>.Bounded<bucketCapacity>) -> Void
    ) {
        Self.forEachBucketIndex { bucketIdx in
            let hash = readHash(at: bucketIdx)
            if hash != Self.empty && hash != Self.deleted {
                let position = readPosition(at: bucketIdx)
                body(bucketIdx, position)
            }
        }
    }

    /// Iterates over all positions in the hash table.
    ///
    /// A simpler variant that only provides positions, not bucket indices or hashes.
    ///
    /// - Parameter body: A closure called with each bounded element position.
    ///
    /// - Complexity: O(n) where n is bucket capacity.
    @inlinable
    package borrowing func eachPosition(_ body: (Index<Element>.Bounded<bucketCapacity>) -> Void) {
        Self.forEachBucketIndex { bucketIdx in
            let hash = readHash(at: bucketIdx)
            if hash != Self.empty && hash != Self.deleted {
                let position = readPosition(at: bucketIdx)
                body(position)
            }
        }
    }

    /// Iterates over all occupied buckets with early exit support.
    ///
    /// - Parameter body: A closure called with bucket index, hash, and bounded position.
    ///   Return `true` to continue iteration, `false` to stop.
    /// - Returns: `true` if iteration completed, `false` if stopped early.
    ///
    /// - Complexity: O(n) where n is bucket capacity.
    @inlinable
    @discardableResult
    package borrowing func eachOccupiedWhile(
        _ body: (_ bucket: BucketIndex, _ hash: Int, _ position: Index<Element>.Bounded<bucketCapacity>) -> Bool
    ) -> Bool {
        // Manual loop required for early exit support
        var bucket: BucketIndex = .zero
        let cap = BucketIndex.Count(Cardinal(UInt(bucketCapacity)))
        while bucket < cap {
            let hash = readHash(at: bucket)
            if hash != Self.empty && hash != Self.deleted {
                let position = readPosition(at: bucket)
                if !body(bucket, hash, position) {
                    return false
                }
            }
            bucket += .one
        }
        return true
    }
}
