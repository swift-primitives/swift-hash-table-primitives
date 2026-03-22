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
public import Ordinal_Primitives
internal import Property_Primitives

extension Hash.Table.Positions where Element: ~Copyable {
    public typealias View = Property<Hash.Table<Element>.Positions, Hash.Table<Element>>.View.Typed<Element>
}

extension Hash.Table where Element: ~Copyable {
    /// Access position update operations.
    @inlinable
    public var positions: Positions.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Positions.View = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property.View.Typed
where Tag == Hash.Table<Element>.Positions, Base == Hash.Table<Element>, Element: ~Copyable {
    /// Decrements all positions greater than `removedPosition`.
    ///
    /// When an element at `removedPosition` is removed from external storage,
    /// all positions greater than `removedPosition` must be decremented.
    ///
    /// - Parameter removedPosition: The typed position that was removed.
    @inlinable
    public mutating func decrement(after removedPosition: Index<Element>) {
        var bucket: Hash.Table<Element>.Bucket.Index = .zero
        let cap = unsafe base.pointee.bucketCapacity
        while bucket < cap {
            let hash = unsafe base.pointee[hash: bucket]
            if hash != Hash.Table<Element>.empty && hash != Hash.Table<Element>.deleted {
                let pos = unsafe base.pointee[position: bucket]
                if pos > removedPosition {
                    unsafe base.pointee[position: bucket] = try! pos.predecessor.exact()
                }
            }
            bucket += .one
        }
    }
}
