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

public import Buffer_Linear_Primitive
import Buffer_Primitive
public import Buffer_Slots_Primitive
import Buffer_Slots_Primitives
public import Hash_Primitives
public import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Storage_Primitive
public import Store_Primitive
public import Store_Split_Primitives

extension Hash.Table where Element: ~Copyable {
    /// Bucket capacity derived from the buffer.
    @inlinable
    package var bucketCapacity: Index<Bucket>.Count {
        _buffer.capacity.retag(Bucket.self)
    }

    /// Hash value at a bucket.
    @inlinable
    package subscript(hash bucket: Bucket.Index) -> Int {
        get { _buffer[metadata: bucket.retag(Int.self)] }
        set { _buffer[metadata: bucket.retag(Int.self)] = newValue }
    }

    /// Element position at a bucket.
    @inlinable
    package subscript(position bucket: Bucket.Index) -> Index<Element> {
        get {
            let raw = _buffer[payload: bucket.retag(Int.self)]
            return Index<Element>(_unchecked: Ordinal(UInt(bitPattern: raw)))
        }
        set {
            _buffer[payload: bucket.retag(Int.self)] = Int(bitPattern: newValue)
        }
    }

    /// The bucket that currently holds the entry for `rank` in the B-7 plane.
    ///
    /// The plane accelerates the DENSE-RANK discipline (positions < count, the
    /// `Hash.Indexed` shape) — its only reader is `decrement(after:)`'s walk.
    /// The engine's wider contract allows arbitrary sparse positions into
    /// external storage; writes for positions beyond the plane are SKIPPED
    /// (such consumers never call the dense fixup, so their plane entries are
    /// never read).
    @inlinable
    package subscript(bucketOfRank rank: Index<Element>) -> Bucket.Index {
        get {
            let raw = _rankToBucket[Index<Int>(_unchecked: Ordinal(UInt(bitPattern: Int(bitPattern: rank))))]
            return Bucket.Index(_unchecked: Ordinal(UInt(bitPattern: raw)))
        }
        set {
            let raw = Int(bitPattern: rank)
            guard raw < Int(bitPattern: _rankToBucket.count) else { return }
            _rankToBucket[Index<Int>(_unchecked: Ordinal(UInt(bitPattern: raw)))] = Int(bitPattern: newValue)
        }
    }
}
