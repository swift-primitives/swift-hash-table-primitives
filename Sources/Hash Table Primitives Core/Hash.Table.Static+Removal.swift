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
    /// Removes an element from the hash table.
    ///
    /// Marks the bucket as deleted (tombstone) to maintain probe chain integrity.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to remove.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the element to remove.
    /// - Returns: The typed position that was removed, or `nil` if not found.
    ///
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    @discardableResult
    public mutating func remove(
        hashValue: Hash.Value,
        equals: (Index<Element>) -> Bool
    ) -> Index<Element>? {
        guard let bucket = bucketIndex(forHash: hashValue, equals: equals) else {
            return nil
        }

        let position = readPosition(at: bucket)
        writeHash(at: bucket, value: Self.deleted)
        _count = _count.subtract.saturating(.one)
        // Note: _occupied does not decrease - tombstones still count as occupied
        return position
    }

    /// Removes the element at a specific bucket index.
    ///
    /// - Parameter bucket: The bucket index to remove.
    /// - Returns: The position that was stored at the bucket.
    ///
    /// - Precondition: The bucket must contain a valid element (not empty or deleted).
    @inlinable
    @discardableResult
    public mutating func remove(atBucket bucket: BucketIndex) -> Index<Element> {
        precondition(
            readHash(at: bucket) != Self.empty && readHash(at: bucket) != Self.deleted,
            "Cannot remove from empty or deleted bucket"
        )
        let position = readPosition(at: bucket)
        writeHash(at: bucket, value: Self.deleted)
        _count = _count.subtract.saturating(.one)
        return position
    }

    /// Clears all buckets (internal helper for Property accessor).
    @inlinable
    package mutating func clearAll() {
        Self.forEachBucketIndex { bucketIdx in
            writeHash(at: bucketIdx, value: Self.empty)
        }
        _count = .zero
        _occupied = .zero
    }

    /// Rehashes the table, removing tombstones.
    ///
    /// Call this after many deletions to reclaim tombstone slots and
    /// improve probe chain performance.
    ///
    /// - Complexity: O(n) where n is bucket capacity.
    @inlinable
    public mutating func rehash() {
        // Collect all active entries
        var entries: [(hash: Int, position: Index<Element>)] = []
        entries.reserveCapacity(Int(bitPattern: _count))

        Self.forEachBucketIndex { bucketIdx in
            let hash = readHash(at: bucketIdx)
            if hash != Self.empty && hash != Self.deleted {
                entries.append((hash: hash, position: readPosition(at: bucketIdx)))
            }
        }

        // Clear all buckets
        Self.forEachBucketIndex { bucketIdx in
            writeHash(at: bucketIdx, value: Self.empty)
        }
        _occupied = .zero

        // Reinsert all entries
        for entry in entries {
            var targetBucket = bucket(for: entry.hash)
            while readHash(at: targetBucket) != Self.empty {
                targetBucket = bucket(after: targetBucket)
            }
            writeHash(at: targetBucket, value: entry.hash)
            writePosition(at: targetBucket, value: entry.position)
            _occupied = _occupied + .one
        }
        // _count unchanged
    }
}
