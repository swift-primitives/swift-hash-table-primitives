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
        hashValue: Int,
        equals: (Index<Element>) -> Bool
    ) -> Index<Element>? {
        guard let bucket = bucketIndex(forHash: hashValue, equals: equals) else {
            return nil
        }

        let position = Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: _positions[bucket])))
        _hashes[bucket] = Self.deleted
        _count = Index<Element>.Count(Cardinal(_count.rawValue.rawValue - 1))
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
    public mutating func remove(atBucket bucket: Int) -> Index<Element> {
        precondition(
            _hashes[bucket] != Self.empty && _hashes[bucket] != Self.deleted,
            "Cannot remove from empty or deleted bucket"
        )
        let position = Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: _positions[bucket])))
        _hashes[bucket] = Self.deleted
        _count = Index<Element>.Count(Cardinal(_count.rawValue.rawValue - 1))
        return position
    }

    /// Removes all elements from the hash table.
    ///
    /// Resets all buckets to empty state, clearing tombstones.
    @inlinable
    public mutating func removeAll() {
        for i in 0..<bucketCapacity {
            _hashes[i] = Self.empty
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
        var entries: [(hash: Int, position: Int)] = []
        entries.reserveCapacity(Int(bitPattern: _count))

        for i in 0..<bucketCapacity {
            let hash = _hashes[i]
            if hash != Self.empty && hash != Self.deleted {
                entries.append((hash: hash, position: _positions[i]))
            }
        }

        // Clear all buckets
        for i in 0..<bucketCapacity {
            _hashes[i] = Self.empty
        }
        _occupied = .zero

        // Reinsert all entries
        for entry in entries {
            var bucket = bucketFor(hash: entry.hash)
            while _hashes[bucket] != Self.empty {
                bucket = nextBucket(bucket)
            }
            _hashes[bucket] = entry.hash
            _positions[bucket] = entry.position
            _occupied = Index<Bucket>.Count(Cardinal(_occupied.rawValue.rawValue + 1))
        }
        // _count unchanged
    }
}
