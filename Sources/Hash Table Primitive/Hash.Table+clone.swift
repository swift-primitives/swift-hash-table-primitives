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

import Affine_Primitives_Standard_Library_Integration
public import Buffer_Linear_Primitive
public import Buffer_Primitive
public import Buffer_Slots_Primitive
public import Buffer_Slots_Primitives
import Cardinal_Primitives
public import Hash_Primitives
public import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
internal import Ordinal_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Contiguous_Primitives
public import Storage_Primitive
public import Store_Primitive
public import Store_Split_Primitives

// MARK: - Explicit deep copy (the composite's clone strategy)
//
// Seed-and-layout-preserving (NO rehash) — the stdlib `copy()` discipline: a clone is a
// verbatim plane copy, so probe chains and bucket positions are identical and cloning
// stays O(capacity) with no hashing. (Growth, by contrast, re-seeds — see `grow()`.)
extension Hash.Table where Element: ~Copyable {
    /// Returns an independent copy with identical layout, seed, and contents.
    ///
    /// - Complexity: O(`capacity`)
    @inlinable
    public borrowing func clone() -> Self {
        var copy = Self(minimumCapacity: .zero)
        var fresh = Buffer<Store.Split<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>, Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>>.Slots(
            capacity: self.bucketCapacity.retag(Int.self),
            metadataInitial: Self.empty
        )
        fresh.fill(payload: 0)
        var freshPlane = Self.makeRankPlane(bucketCapacity: self.bucketCapacity)
        var bucket: Index<Int> = .zero
        let end = self.bucketCapacity.retag(Int.self).map(Ordinal.init)
        while bucket < end {
            fresh[metadata: bucket] = _buffer[metadata: bucket]
            fresh[payload: bucket] = _buffer[payload: bucket]
            freshPlane[bucket] = _rankToBucket[bucket]
            bucket += .one
        }
        copy._buffer = fresh
        copy._rankToBucket = freshPlane
        copy._count = _count
        copy._seed = _seed
        return copy
    }
}
