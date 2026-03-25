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

extension Hash.Occupied.View {
    /// An iterator that scans occupied buckets from pointer-based storage.
    ///
    /// Linear scan through all buckets, skipping empty (`0`) and deleted
    /// (`Int.min`) sentinels. Yields `Hash.Occupied<Source>` for each
    /// occupied bucket.
    @unsafe public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        let _hashes: UnsafePointer<Int>

        @usableFromInline
        let _positions: UnsafePointer<Int>

        @usableFromInline
        let _capacity: Hash.Table<Source>.Bucket.Index.Count

        @usableFromInline
        var _index: Hash.Table<Source>.Bucket.Index

        @usableFromInline
        var _element: Hash.Occupied<Source>? = nil

        @inlinable
        package init(hashes: UnsafePointer<Int>, positions: UnsafePointer<Int>, capacity: Hash.Table<Source>.Bucket.Index.Count) {
            unsafe self._hashes = hashes
            unsafe self._positions = positions
            unsafe (self._capacity = capacity)
            unsafe (self._index = .zero)
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
            guard let value = unsafe next() else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            unsafe (_element = value)
            let span = unsafe Span(_unsafeStart: ptr, count: 1)
            return unsafe _overrideLifetime(span, mutating: &self)
        }

        @inlinable
        public mutating func next() -> Hash.Occupied<Source>? {
            while unsafe _index < _capacity {
                let bucket = unsafe _index
                unsafe (_index += .one)
                let hash = unsafe _hashes[bucket]
                if hash != Hash.Table<Source>.empty && hash != Hash.Table<Source>.deleted {
                    let position = Index<Source>(
                        __unchecked: (), Ordinal(UInt(bitPattern: unsafe _positions[bucket]))
                    )
                    return Hash.Occupied(bucket: bucket, hash: hash, position: position)
                }
            }
            return nil
        }
    }
}
