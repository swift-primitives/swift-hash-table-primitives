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
    @inlinable
    var shouldGrow: Bool {
        let hashCapacity = Int(bitPattern: bucketCapacity)
        let occupied = Int(bitPattern: _occupied)
        // Grow when occupied exceeds 70% of capacity
        return occupied * 10 >= hashCapacity * 7
    }
}
