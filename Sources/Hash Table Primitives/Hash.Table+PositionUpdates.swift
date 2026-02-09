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
public import Property_Primitives

extension Hash.Table where Element: ~Copyable {
    /// Access position update operations.
    @inlinable
    public var positions: Property<Positions, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Positions, Self>.View.Typed(&self)
        }
        mutating _modify {
            var view = unsafe Property<Positions, Self>.View.Typed<Element>(&self)
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
    @_lifetime(&self)
    @inlinable
    public mutating func decrement(after removedPosition: Index<Element>) {
        let cap = Int(bitPattern: unsafe base.pointee.bucketCapacity)
        for i in 0..<cap {
            let bucketIdx = Hash.Table<Element>.BucketIndex(
                __unchecked: (), Ordinal(UInt(i))
            )
            let hash = unsafe base.pointee[hash: bucketIdx]
            if hash != Hash.Table<Element>.empty && hash != Hash.Table<Element>.deleted {
                let pos = unsafe base.pointee[position: bucketIdx]
                if pos > removedPosition {
                    unsafe base.pointee[position: bucketIdx] = try! pos.predecessor.exact()
                }
            }
        }
    }
}
