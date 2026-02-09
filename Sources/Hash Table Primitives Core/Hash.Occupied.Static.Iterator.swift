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

extension Hash.Occupied.Static {
    /// An iterator that scans occupied buckets from InlineArray storage.
    ///
    /// Same linear scan as `View.Iterator` but reads from copied `InlineArray`
    /// instead of pointers.
    @safe
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _hashes: InlineArray<bucketCapacity, Int>

        @usableFromInline
        let _positions: InlineArray<bucketCapacity, Int>

        @usableFromInline
        var _index: Int

        @inlinable
        package init(hashes: InlineArray<bucketCapacity, Int>, positions: InlineArray<bucketCapacity, Int>) {
            self._hashes = hashes
            self._positions = positions
            self._index = 0
        }

        @inlinable
        public mutating func next() -> Hash.Occupied<Source>? {
            while _index < bucketCapacity {
                let i = _index
                _index &+= 1
                let hash = _hashes[i]
                if hash != Hash.Table<Source>.empty && hash != Hash.Table<Source>.deleted {
                    let bucket = Hash.Table<Source>.BucketIndex(
                        __unchecked: (), Ordinal(UInt(i))
                    )
                    let position = Index<Source>(
                        __unchecked: (), Ordinal(UInt(bitPattern: _positions[i]))
                    )
                    return Hash.Occupied(bucket: bucket, hash: hash, position: position)
                }
            }
            return nil
        }
    }
}
