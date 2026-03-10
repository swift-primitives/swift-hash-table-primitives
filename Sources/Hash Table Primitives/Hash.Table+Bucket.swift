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

public import Hash_Table_Primitives_Core
public import Property_Primitives

extension Hash.Table.BucketOps where Element: ~Copyable {
    public typealias View = Property<Hash.Table<Element>.BucketOps, Hash.Table<Element>>.View.Typed<Element>
}

extension Hash.Table where Element: ~Copyable {
    /// Maps a normalized hash into the bucket space for the given capacity.
    @inlinable
    package static func bucket(
        for hash: Int,
        capacity: Index<Bucket>.Count
    ) -> Bucket.Index {
        Bucket.Index(__unchecked: (), Ordinal(UInt(bitPattern: hash)) % capacity.rawValue)
    }

    /// Access bucket operations.
    ///
    /// Usage:
    /// - `table.bucket.for(hash: hashValue)`
    /// - `table.bucket.next(currentBucket)`
    @inlinable
    public var bucket: BucketOps.View {
        mutating _read {
            yield unsafe .init(&self)
        }
    }
}

extension Property.View.Typed
where Tag == Hash.Table<Element>.BucketOps, Base == Hash.Table<Element>, Element: ~Copyable {
    /// Computes the bucket for a normalized hash value.
    ///
    /// Maps the normalized hash value into the cyclic bucket space [0, capacity)
    /// using unsigned modular reduction.
    ///
    /// - Parameter hash: A normalized hash value (output of `normalize()`).
    @inlinable
    public func `for`(hash: Int) -> Hash.Table<Element>.Bucket.Index {
        let capacity = unsafe base.pointee.bucketCapacity
        return Hash.Table<Element>.bucket(for: hash, capacity: capacity)
    }

    /// Computes the next bucket in the probe sequence.
    ///
    /// Uses cyclic arithmetic for wrap-around.
    ///
    /// Usage: `table.bucket.next(currentBucket)`
    @inlinable
    public func next(_ bucket: Hash.Table<Element>.Bucket.Index) -> Hash.Table<Element>.Bucket.Index {
        let capacity = unsafe base.pointee.bucketCapacity
        return Hash.Table<Element>.Bucket.Index.Modular.successor(of: bucket, capacity: capacity)
    }
}
