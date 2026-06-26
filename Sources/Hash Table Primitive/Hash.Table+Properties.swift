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

import Affine_Primitives_Standard_Library_Integration
public import Hash_Primitives
public import Index_Primitives

extension Hash.Table where Element: ~Copyable {
    /// The number of elements in the hash table.
    @inlinable
    public var count: Index<Element>.Count {
        _count
    }

    /// Whether the hash table is empty.
    @inlinable
    public var isEmpty: Bool {
        _count == .zero
    }

    /// The current bucket capacity of the hash table.
    @inlinable
    public var capacity: Index<Bucket>.Count {
        bucketCapacity
    }

    /// Whether the hash table should grow.
    ///
    /// Tombstone-free, so occupancy == count; grow when count exceeds 70% of capacity.
    @inlinable
    var shouldGrow: Bool {
        typealias Scale = Affine.Discrete.Ratio<Bucket, Bucket>
        return _count.retag(Bucket.self) * Scale(10) >= bucketCapacity * Scale(7)
    }
}
