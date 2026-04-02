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
    ///
    /// When an element is removed from external storage, all positions after
    /// the removed position shift down by one. The predecessor is safe because
    /// `pos > removedPosition` guarantees `pos > 0`.
    @inlinable
    package mutating func decrementAllPositions(after removedPosition: Index<Element>.Bounded<bucketCapacity>) {
        Self.forEachBucket { bucketIdx in
            let hash = readHash(at: bucketIdx)
            if hash != Self.empty && hash != Self.deleted {
                let pos = readPosition(at: bucketIdx)
                if pos > removedPosition {
                    writePosition(at: bucketIdx, value: pos.map { $0.predecessor()! })
                }
            }
        }
    }

    /// Updates position for an element with the given hash value (internal helper for Property accessor).
    @inlinable
    @discardableResult
    package mutating func updatePositionInternal(
        forHash hashValue: Hash.Value,
        equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool,
        newPosition: Index<Element>.Bounded<bucketCapacity>
    ) -> Bool {
        guard let index = index(forHash: hashValue, equals: equals) else {
            return false
        }
        writePosition(at: index, value: newPosition)
        return true
    }

    /// Updates position for an element, passing a context value through
    /// to the equality closure (internal helper for Property accessor).
    @inlinable
    @discardableResult
    package mutating func updatePositionInternal<Context: ~Copyable>(
        forHash hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Index<Element>.Bounded<bucketCapacity>, borrowing Context) -> Bool,
        newPosition: Index<Element>.Bounded<bucketCapacity>
    ) -> Bool {
        guard let index = index(forHash: hashValue, context: context, equals: equals) else {
            return false
        }
        writePosition(at: index, value: newPosition)
        return true
    }

    /// Updates position at a specific bucket index (internal helper for Property accessor).
    @inlinable
    package mutating func updatePositionInternal(atBucket bucket: Bucket.Index, newPosition: Index<Element>.Bounded<bucketCapacity>) {
        precondition(
            readHash(at: bucket) != Self.empty && readHash(at: bucket) != Self.deleted,
            "Cannot update position of empty or deleted bucket"
        )
        writePosition(at: bucket, value: newPosition)
    }
}
