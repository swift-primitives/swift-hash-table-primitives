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
    /// Decrements all positions greater than `removedPosition` (internal helper for Property accessor).
    @inlinable
    package mutating func decrementAllPositions(after removedPosition: Index<Element>) {
        Self.forEachBucketIndex { bucketIdx in
            let hash = readHash(at: bucketIdx)
            if hash != Self.empty && hash != Self.deleted {
                let pos = readPosition(at: bucketIdx)
                if pos > removedPosition {
                    writePosition(at: bucketIdx, value: try! pos.predecessor.exact())
                }
            }
        }
    }

    /// Updates position for an element with the given hash value (internal helper for Property accessor).
    @inlinable
    @discardableResult
    package mutating func updatePositionInternal(
        forHash hashValue: Hash.Value,
        equals: (Index<Element>) -> Bool,
        newPosition: Index<Element>
    ) -> Bool {
        guard let bucket = bucketIndex(forHash: hashValue, equals: equals) else {
            return false
        }
        writePosition(at: bucket, value: newPosition)
        return true
    }

    /// Updates position at a specific bucket index (internal helper for Property accessor).
    @inlinable
    package mutating func updatePositionInternal(atBucket bucket: BucketIndex, newPosition: Index<Element>) {
        precondition(
            readHash(at: bucket) != Self.empty && readHash(at: bucket) != Self.deleted,
            "Cannot update position of empty or deleted bucket"
        )
        writePosition(at: bucket, value: newPosition)
    }
}
