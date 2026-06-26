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

public import Hash_Primitives
public import Index_Primitives
internal import Property_Primitives

extension Hash.Table.ForEach where Element: ~Copyable {
    /// The mutable accessor view for iteration operations.
    public typealias View = Property<Hash.Table<Element>.ForEach, Hash.Table<Element>>.Inout.Typed<Element>
}

extension Hash.Table where Element: ~Copyable {
    /// Access forEach operations.
    ///
    /// Usage: `table.forEach.occupied { bucket, position in ... }`
    @inlinable
    public var forEach: ForEach.View {
        mutating _read {
            yield.init(&self)
        }
    }
}

extension Property.Inout.Typed
where Tag == Hash.Table<Element>.ForEach, Base == Hash.Table<Element>, Element: ~Copyable {
    /// Iterates over all occupied buckets (non-empty, non-deleted).
    ///
    /// Usage: `table.forEach.occupied { bucket, position in ... }`
    ///
    /// - Parameter body: A closure called with each occupied bucket's index and stored position.
    @inlinable
    public func occupied(_ body: (Hash.Table<Element>.Bucket.Index, Index<Element>) -> Void) {
        var bucket: Hash.Table<Element>.Bucket.Index = .zero
        let cap = base.value.bucketCapacity
        while bucket < cap {
            let hash = base.value[hash: bucket]
            if hash != Hash.Table<Element>.empty {
                let position = base.value[position: bucket]
                body(bucket, position)
            }
            bucket += .one
        }
    }
}
