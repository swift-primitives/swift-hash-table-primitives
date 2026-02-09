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

extension Hash.Table.Static where Element: ~Copyable {
    /// Access bucket operations.
    ///
    /// Usage:
    /// - `table.bucket.for(hash: hashValue)`
    /// - `table.bucket.next(currentBucket)`
    @inlinable
    public var bucket: Property<Hash.Table<Element>.BucketOps, Self>.View.Typed<Element>.Valued<bucketCapacity> {
        mutating _read {
            yield unsafe .init(&self)
        }
    }
}

extension Property.View.Typed.Valued
where Tag == Hash.Table<Element>.BucketOps,
      Base == Hash.Table<Element>.Static<n>,
      Element: ~Copyable
{
    /// Computes the bucket for a normalized hash value.
    ///
    /// - Parameter hash: A normalized hash value (output of `normalize()`).
    @inlinable
    public func `for`(hash: Int) -> Hash.Table<Element>.BucketIndex {
        unsafe base.pointee.bucket(for: hash)
    }

    /// Computes the next bucket in the probe sequence.
    ///
    /// - Parameter current: The current bucket index.
    @inlinable
    public func next(_ current: Hash.Table<Element>.BucketIndex) -> Hash.Table<Element>.BucketIndex {
        unsafe base.pointee.bucket(after: current)
    }
}
