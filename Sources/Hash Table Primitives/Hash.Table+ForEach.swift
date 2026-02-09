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

extension Hash.Table where Element: ~Copyable {
    /// Access forEach operations.
    ///
    /// Usage: `table.forEach.occupied { bucket, position in ... }`
    @inlinable
    public var forEach: Property<ForEach, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<ForEach, Self>.View.Typed(&self)
        }
    }
}

extension Property.View.Typed
where Tag == Hash.Table<Element>.ForEach, Base == Hash.Table<Element>, Element: ~Copyable {
    /// Iterates over all occupied buckets (non-empty, non-deleted).
    ///
    /// Usage: `table.forEach.occupied { bucket, position in ... }`
    ///
    /// - Parameter body: A closure called with each occupied bucket's index and stored position.
    @inlinable
    public func occupied(_ body: (Hash.Table<Element>.BucketIndex, Index<Element>) -> Void) {
        let cap = Int(bitPattern: unsafe base.pointee.bucketCapacity)
        for i in 0..<cap {
            let bucketIdx = Hash.Table<Element>.BucketIndex(
                __unchecked: (), Ordinal(UInt(i))
            )
            let hash = unsafe base.pointee[hash: bucketIdx]
            if hash != Hash.Table<Element>.empty && hash != Hash.Table<Element>.deleted {
                let position = unsafe base.pointee[position: bucketIdx]
                body(bucketIdx, position)
            }
        }
    }
}
