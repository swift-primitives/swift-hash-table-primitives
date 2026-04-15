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
    ///
    /// ## Safety Invariant
    ///
    /// `Hash.Occupied.View` holds raw `UnsafePointer<Int>` fields pointing into
    /// a `Hash.Table`'s backing buffer. The pointers must outlive the view, and
    /// the underlying `Hash.Table` must not be mutated or deallocated while the
    /// view is live. The caller is responsible for ensuring these lifetime and
    /// non-mutation invariants when sending the view across threads.
    ///
    /// ## Intended Use
    ///
    /// - Non-mutating iteration of occupied buckets from any context that holds
    ///   the pointers live.
    /// - Transferring an iteration snapshot to another thread for read-only
    ///   processing while the source table is frozen.
    ///
    /// ## Non-Goals
    ///
    /// - Does not own the pointed-to memory — caller manages buffer lifetime.
    /// - Does not synchronize access — concurrent mutation of the underlying
    ///   `Hash.Table` during iteration is undefined behavior.
    /// - The outer `@unsafe` on the struct already signals pointer-safety
    ///   requirements; the Sendable conformance adds the cross-thread dimension.
    @unsafe public struct View: Copyable, @unsafe @unchecked Sendable {
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
            unsafe (self._capacity = capacity)
            unsafe (self._count = count)
        }

        @inlinable
        public func makeIterator() -> Iterator {
            unsafe Iterator(hashes: _hashes, positions: _positions, capacity: _capacity)
        }
    }
}
