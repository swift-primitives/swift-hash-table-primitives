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
public import Ordinal_Primitives

extension Hash.Table where Element: ~Copyable {
    /// Access bucket operations.
    ///
    /// Usage:
    /// - `table.bucket.for(hash: hashValue)`
    /// - `table.bucket.next(currentBucket)`
    @inlinable
    public var bucket: Property<BucketOps, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<BucketOps, Self>.View.Typed(&self)
        }
    }
}

extension Property.View.Typed
where Tag == Hash.Table<Element>.BucketOps, Base == Hash.Table<Element>, Element: ~Copyable {
    /// Computes the bucket for a hash value.
    ///
    /// Usage: `table.bucket.for(hash: hashValue)`
    @inlinable
    public func `for`(hash: Int) -> Hash.Table<Element>.BucketIndex {
        let cap = Int(unsafe base.pointee._storage.header.capacity.rawValue.rawValue)
        let normalized = Hash.Table<Element>.normalize(hash)
        let bucketInt = normalized & (cap - 1)
        return Hash.Table<Element>.BucketIndex(__unchecked: (), Ordinal(UInt(bucketInt)))
    }

    /// Computes the next bucket in the probe sequence.
    ///
    /// Usage: `table.bucket.next(currentBucket)`
    @inlinable
    public func next(_ bucket: Hash.Table<Element>.BucketIndex) -> Hash.Table<Element>.BucketIndex {
        let cap = Int(unsafe base.pointee._storage.header.capacity.rawValue.rawValue)
        let next = (Int(bitPattern: bucket.position.rawValue) + 1) & (cap - 1)
        return Hash.Table<Element>.BucketIndex(__unchecked: (), Ordinal(UInt(next)))
    }
}
