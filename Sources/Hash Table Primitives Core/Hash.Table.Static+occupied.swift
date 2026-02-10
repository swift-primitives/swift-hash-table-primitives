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

extension Hash.Table.Static where Element: Copyable {
    /// A sequence view of all occupied buckets in the inline hash table.
    ///
    /// Returns a copy of the inline hash and position arrays wrapped in
    /// a sequence view. Each element yields a `Hash.Occupied<Element>`
    /// containing the bucket index, stored hash, and typed position.
    ///
    /// ```swift
    /// for slot in table.occupied {
    ///     print(slot.bucket, slot.hash, slot.position)
    /// }
    /// ```
    @inlinable
    public var occupied: Hash.Occupied<Element>.Static<bucketCapacity> {
        Hash.Occupied<Element>.Static(
            hashes: _hashes, positions: _positions,
            count: _count
        )
    }
}
