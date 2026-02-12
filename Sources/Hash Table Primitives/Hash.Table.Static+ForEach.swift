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
    public enum ForEach {
        public typealias View = Property<Hash.Table<Element>.ForEach, Hash.Table<Element>.Static<bucketCapacity>>.View.Typed<Element>.Valued<bucketCapacity>
    }
}

extension Hash.Table.Static where Element: ~Copyable {
    /// Access forEach operations.
    ///
    /// Usage:
    /// - `table.forEach.occupied { bucket, position in ... }`
    /// - `table.forEach.position { position in ... }`
    @inlinable
    public var forEach: ForEach.View {
        mutating _read { yield unsafe .init(&self) }
    }
}

extension Property.View.Typed.Valued
where Tag == Hash.Table<Element>.ForEach,
      Base == Hash.Table<Element>.Static<n>,
      Element: ~Copyable
{
    /// Iterates over all occupied buckets (non-empty, non-deleted).
    ///
    /// - Parameter body: A closure called with each occupied bucket's index and bounded position.
    @inlinable
    public func occupied(
        _ body: (Hash.Table<Element>.BucketIndex, Index<Element>.Bounded<n>) -> Void
    ) {
        unsafe base.pointee.eachOccupied(body)
    }

    /// Iterates over all bounded element positions in the hash table.
    ///
    /// - Parameter body: A closure called with each bounded element position.
    @inlinable
    public func position(_ body: (Index<Element>.Bounded<n>) -> Void) {
        unsafe base.pointee.eachPosition(body)
    }
}
