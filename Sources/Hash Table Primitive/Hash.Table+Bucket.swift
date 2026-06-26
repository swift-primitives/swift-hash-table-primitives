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

public import Cyclic_Index_Primitives
public import Hash_Primitives
public import Index_Primitives
import Ordinal_Primitives
internal import Property_Primitives

extension Hash.Table.Bucket.Ops where Element: ~Copyable {
    /// The mutable accessor view for bucket operations.
    public typealias View = Property<Hash.Table<Element>.Bucket.Ops, Hash.Table<Element>>.Inout.Typed<Element>
}

extension Hash.Table where Element: ~Copyable {
    /// Maps a normalized hash into the bucket space for the given capacity, mixing
    /// the probe seed (per-instance probe order; see the decl's `## Seeding`).
    @inlinable
    package static func bucket(
        for hash: Int,
        seed: Int,
        capacity: Index<Bucket>.Count
    ) -> Bucket.Index {
        Bucket.Index(_unchecked: Ordinal(UInt(bitPattern: hash ^ seed)) % capacity.underlying)
    }

    /// Access bucket operations.
    ///
    /// Usage:
    /// - `table.bucket.for(hash: hashValue)`
    /// - `table.bucket.next(currentBucket)`
    @inlinable
    public var bucket: Bucket.Ops.View {
        mutating _read {
            yield.init(&self)
        }
    }
}

extension Property.Inout.Typed
where Tag == Hash.Table<Element>.Bucket.Ops, Base == Hash.Table<Element>, Element: ~Copyable {
    /// Computes the bucket for a normalized hash value.
    ///
    /// Maps the normalized hash value into the cyclic bucket space [0, capacity)
    /// using unsigned modular reduction.
    ///
    /// - Parameter hash: A normalized hash value (output of `normalize()`).
    /// - Returns: The bucket index where the hash's probe sequence begins.
    @inlinable
    public func `for`(hash: Int) -> Hash.Table<Element>.Bucket.Index {
        let capacity = base.value.bucketCapacity
        return Hash.Table<Element>.bucket(for: hash, seed: base.value._seed, capacity: capacity)
    }

    /// Computes the next bucket in the probe sequence.
    ///
    /// Uses cyclic arithmetic for wrap-around.
    ///
    /// Usage: `table.bucket.next(currentBucket)`
    @inlinable
    public func next(_ bucket: Hash.Table<Element>.Bucket.Index) -> Hash.Table<Element>.Bucket.Index {
        let capacity = base.value.bucketCapacity
        return Hash.Table<Element>.Bucket.Index.Modular.successor(of: bucket, capacity: capacity)
    }
}
