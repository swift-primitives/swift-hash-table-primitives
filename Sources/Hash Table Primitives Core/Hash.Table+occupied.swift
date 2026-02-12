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

extension Hash.Table where Element: Copyable {
    /// A sequence view of all occupied buckets in the hash table.
    ///
    /// Returns a lightweight view capturing the hash and position pointers.
    /// Each element yields a `Hash.Occupied<Element>` containing the bucket
    /// index, stored hash, and typed position.
    ///
    /// ```swift
    /// for slot in table.occupied {
    ///     print(slot.bucket, slot.hash, slot.position)
    /// }
    /// ```
    @inlinable
    public var occupied: Hash.Occupied<Element>.View {
        let hashes: UnsafePointer<Int> = unsafe _buffer.metadataPointer
        let positions: UnsafePointer<Int> = unsafe UnsafePointer(_buffer.pointer(at: .zero))
        let capacity = _buffer.capacity.retag(Hash.Table<Element>.Bucket.self)
        let count = _count
        return unsafe Hash.Occupied<Element>.View(
            hashes: hashes, positions: positions, capacity: capacity, count: count
        )
    }
}
