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

import Cardinal_Primitives

extension Hash.Occupied.Static {
    /// An iterator that scans occupied buckets from InlineArray storage.
    ///
    /// Same linear scan as `View.Iterator` but reads from copied `InlineArray`
    /// instead of pointers.
    @safe
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        let _hashes: InlineArray<bucketCapacity, Int>

        @usableFromInline
        let _positions: InlineArray<bucketCapacity, Int>

        @usableFromInline
        let _capacity: Hash.Table<Source>.BucketIndex.Count

        @usableFromInline
        var _index: Hash.Table<Source>.BucketIndex

        @usableFromInline
        var _spanBuffer: [Hash.Occupied<Source>] = []

        @inlinable
        package init(hashes: InlineArray<bucketCapacity, Int>, positions: InlineArray<bucketCapacity, Int>) {
            self._hashes = hashes
            self._positions = positions
            self._capacity = Hash.Table<Source>.BucketIndex.Count(Cardinal(UInt(bucketCapacity)))
            self._index = .zero
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Hash.Occupied<Source>> {
            _spanBuffer.removeAll(keepingCapacity: true)
            var remaining = Int(maximumCount.rawValue)
            while remaining > 0, _index < _capacity {
                let bucket = _index
                _index += .one
                let hash = _hashes[bucket]
                if hash != Hash.Table<Source>.empty && hash != Hash.Table<Source>.deleted {
                    let position = Index<Source>(
                        __unchecked: (), Ordinal(UInt(bitPattern: _positions[bucket]))
                    )
                    _spanBuffer.append(Hash.Occupied(bucket: bucket, hash: hash, position: position))
                    remaining -= 1
                }
            }
            return _spanBuffer.span
        }

        @_lifetime(self: immortal)
        @inlinable
        public mutating func next() -> Hash.Occupied<Source>? {
            while _index < _capacity {
                let bucket = _index
                _index += .one
                let hash = _hashes[bucket]
                if hash != Hash.Table<Source>.empty && hash != Hash.Table<Source>.deleted {
                    let position = Index<Source>(
                        __unchecked: (), Ordinal(UInt(bitPattern: _positions[bucket]))
                    )
                    return Hash.Occupied(bucket: bucket, hash: hash, position: position)
                }
            }
            return nil
        }
    }
}
