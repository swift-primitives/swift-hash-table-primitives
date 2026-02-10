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

extension Hash.Occupied.View {
    /// An iterator that scans occupied buckets from pointer-based storage.
    ///
    /// Linear scan through all buckets, skipping empty (`0`) and deleted
    /// (`Int.min`) sentinels. Yields `Hash.Occupied<Source>` for each
    /// occupied bucket.
    @safe
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _hashes: UnsafePointer<Int>

        @usableFromInline
        let _positions: UnsafePointer<Int>

        @usableFromInline
        let _capacity: Hash.Table<Source>.BucketIndex.Count

        @usableFromInline
        var _index: Hash.Table<Source>.BucketIndex

        @inlinable
        package init(hashes: UnsafePointer<Int>, positions: UnsafePointer<Int>, capacity: Hash.Table<Source>.BucketIndex.Count) {
            unsafe self._hashes = hashes
            unsafe self._positions = positions
            self._capacity = capacity
            self._index = .zero
        }

        @inlinable
        public mutating func next() -> Hash.Occupied<Source>? {
            while _index < _capacity {
                let bucket = _index
                _index += .one
                let hash = unsafe _hashes[position: bucket]
                if hash != Hash.Table<Source>.empty && hash != Hash.Table<Source>.deleted {
                    let position = Index<Source>(
                        __unchecked: (), Ordinal(UInt(bitPattern: unsafe _positions[position: bucket]))
                    )
                    return Hash.Occupied(bucket: bucket, hash: hash, position: position)
                }
            }
            return nil
        }
    }
}
