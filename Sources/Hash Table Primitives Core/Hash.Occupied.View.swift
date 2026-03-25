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

extension Hash.Occupied where Source: Copyable {
    /// A pointer-based view for iterating occupied buckets of a heap `Hash.Table`.
    ///
    /// Captures hash and position pointers without requiring exclusive access,
    /// enabling iteration from non-mutating contexts.
    @unsafe public struct View: Copyable, @unchecked Sendable {
        @usableFromInline
        let _hashes: UnsafePointer<Int>

        @usableFromInline
        let _positions: UnsafePointer<Int>

        @usableFromInline
        let _capacity: Hash.Table<Source>.Bucket.Index.Count

        @usableFromInline
        package let _count: Index<Source>.Count

        @inlinable
        package init(hashes: UnsafePointer<Int>, positions: UnsafePointer<Int>, capacity: Hash.Table<Source>.Bucket.Index.Count, count: Index<Source>.Count) {
            unsafe self._hashes = hashes
            unsafe self._positions = positions
            self._capacity = capacity
            self._count = count
        }

        @inlinable
        public func makeIterator() -> Iterator {
            unsafe Iterator(hashes: _hashes, positions: _positions, capacity: _capacity)
        }
    }
}
