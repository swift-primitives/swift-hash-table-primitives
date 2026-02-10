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
    /// An InlineArray-copy view for iterating occupied buckets of a `Hash.Table.Static`.
    ///
    /// Copies the inline hash and position arrays so iteration does not
    /// require a pointer into stack storage (which would dangle on temporaries).
    @safe
    public struct Static<let bucketCapacity: Int>: Copyable, Sendable {
        @usableFromInline
        let _hashes: InlineArray<bucketCapacity, Int>

        @usableFromInline
        let _positions: InlineArray<bucketCapacity, Int>

        @usableFromInline
        package let _count: Index<Source>.Count

        @inlinable
        package init(hashes: InlineArray<bucketCapacity, Int>, positions: InlineArray<bucketCapacity, Int>, count: Index<Source>.Count) {
            self._hashes = hashes
            self._positions = positions
            self._count = count
        }

        @inlinable
        public func makeIterator() -> Iterator {
            Iterator(hashes: _hashes, positions: _positions)
        }
    }
}
