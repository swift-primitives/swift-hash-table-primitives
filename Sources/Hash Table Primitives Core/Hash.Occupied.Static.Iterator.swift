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
        let _capacity: Hash.Table<Source>.Bucket.Index.Count

        @usableFromInline
        var _index: Hash.Table<Source>.Bucket.Index

        @usableFromInline
        var _element: Hash.Occupied<Source>? = nil

        @inlinable
        package init(hashes: InlineArray<bucketCapacity, Int>, positions: InlineArray<bucketCapacity, Int>) {
            self._hashes = hashes
            self._positions = positions
            self._capacity = Hash.Table<Source>.Bucket.Index.Count(Cardinal(UInt(bucketCapacity)))
            self._index = .zero
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Hash.Occupied<Source>> {
            let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
                unsafe UnsafePointer<Hash.Occupied<Source>>(
                    unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Hash.Occupied<Source>.self)
                )
            }
            guard maximumCount > .zero else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            guard let value = next() else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            _element = value
            let span = unsafe Span(_unsafeStart: ptr, count: 1)
            return unsafe _overrideLifetime(span, mutating: &self)
        }

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
