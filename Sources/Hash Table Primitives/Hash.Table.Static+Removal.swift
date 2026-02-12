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
    public enum Remove {
        public typealias View = Property<Hash.Table<Element>.Remove, Hash.Table<Element>.Static<bucketCapacity>>.View.Typed<Element>.Valued<bucketCapacity>
    }
}

extension Hash.Table.Static where Element: ~Copyable {
    /// Access remove operations.
    @inlinable
    public var remove: Remove.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Remove.View = unsafe .init(&self); yield &view }
    }
}

extension Property.View.Typed.Valued
where Tag == Hash.Table<Element>.Remove,
      Base == Hash.Table<Element>.Static<n>,
      Element: ~Copyable
{
    /// Removes all elements from the hash table.
    ///
    /// Resets all buckets to empty state, clearing tombstones.
    @_lifetime(&self)
    @inlinable
    public mutating func all() {
        unsafe base.pointee.clearAll()
    }
}
