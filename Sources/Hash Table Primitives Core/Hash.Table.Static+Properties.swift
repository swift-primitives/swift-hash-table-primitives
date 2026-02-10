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
    /// The number of active elements in the hash table.
    @inlinable
    public var count: Index<Element>.Count { _count }

    /// Whether the hash table is empty.
    @inlinable
    public var isEmpty: Bool { _count == .zero }

    /// The number of occupied buckets (including deleted tombstones).
    @inlinable
    public var occupancy: BucketIndex.Count { _occupied }

    /// The bucket capacity (compile-time constant).
    @inlinable
    public var capacity: BucketIndex.Count {
        BucketIndex.Count(Cardinal(UInt(bucketCapacity)))
    }

    /// Whether the hash table should grow (is at or above 70% load factor).
    ///
    /// Since inline hash tables cannot grow, this indicates when the table
    /// is too full for efficient operations. Use this to detect when to
    /// spill to heap storage in small-buffer optimization patterns.
    @inlinable
    public var shouldGrow: Bool {
        // Grow when occupied exceeds 70% of capacity
        typealias Scale = Affine.Discrete.Ratio<Bucket, Bucket>
        return _occupied * Scale(10) >= capacity * Scale(7)
    }

    /// Whether the hash table is completely full.
    ///
    /// When `true`, no more elements can be inserted.
    @inlinable
    public var isFull: Bool {
        _occupied >= capacity
    }
}
