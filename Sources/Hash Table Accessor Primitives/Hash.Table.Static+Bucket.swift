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
internal import Property_Primitives

extension Hash.Table.Static where Element: ~Copyable {
    public enum Ops {
        public typealias View = Property<Hash.Table<Element>.Bucket.Ops, Hash.Table<Element>.Static<bucketCapacity>>.View.Typed<Element>.Valued<bucketCapacity>
    }
}

extension Hash.Table.Static where Element: ~Copyable {
    /// Access bucket operations.
    ///
    /// Usage:
    /// - `table.bucket.for(hash: hashValue)`
    /// - `table.bucket.next(currentBucket)`
    @inlinable
    public var bucket: Ops.View {
        mutating _read { yield unsafe .init(&self) }
    }
}

extension Property.View.Typed.Valued
where Tag == Hash.Table<Element>.Bucket.Ops,
      Base == Hash.Table<Element>.Static<n>,
      Element: ~Copyable
{
    /// Computes the bucket for a normalized hash value.
    ///
    /// - Parameter hash: A normalized hash value (output of `normalize()`).
    @inlinable
    public func `for`(hash: Int) -> Hash.Table<Element>.Bucket.Index {
        unsafe base.value.bucket(for: hash)
    }

    /// Computes the next bucket in the probe sequence.
    ///
    /// - Parameter current: The current bucket index.
    @inlinable
    public func next(_ current: Hash.Table<Element>.Bucket.Index) -> Hash.Table<Element>.Bucket.Index {
        unsafe base.value.bucket(after: current)
    }
}
