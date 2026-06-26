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
import Ordinal_Primitives
internal import Property_Primitives

extension Hash.Table.Positions where Element: ~Copyable {
    /// The mutable accessor view for position-update operations.
    public typealias View = Property<Hash.Table<Element>.Positions, Hash.Table<Element>>.Inout.Typed<Element>
}

extension Hash.Table where Element: ~Copyable {
    /// Access position update operations.
    @inlinable
    public var positions: Positions.View {
        mutating _read {
            yield.init(&self)
        }
        mutating _modify {
            var view: Positions.View = .init(&self)
            yield &view
        }
    }
}

extension Property.Inout.Typed
where Tag == Hash.Table<Element>.Positions, Base == Hash.Table<Element>, Element: ~Copyable {
    /// Decrements all positions greater than `removedPosition` — O(n − rank)
    /// via the rank→bucket back-pointer plane (B-7): the walk visits exactly
    /// the live ranks above the removed one and retargets each entry's bucket
    /// payload directly.
    ///
    /// The prior Θ(bucketCapacity) full-table sweep is
    /// retired, and its load-coupled back>front timing anomaly (the
    /// inversion) dies with it (REPORT-engine-fix-W1 §3).
    ///
    /// When an element at `removedPosition` is removed from external storage,
    /// all positions greater than `removedPosition` must be decremented.
    ///
    /// - Precondition: the removed entry's bucket has already been retired
    ///   (the engine count excludes it) — the established call order at
    ///   `Hash.Indexed+Engine.swift`'s removal dance. The walk's upper bound
    ///   is the post-removal count.
    ///
    /// - Parameter removedPosition: The typed position that was removed.
    @inlinable
    public mutating func decrement(after removedPosition: Index<Element>) {
        let removedRaw = Int(bitPattern: removedPosition)
        var rank = Index<Element>(_unchecked: Ordinal(UInt(bitPattern: removedRaw + 1)))
        let end = base.value._count.map(Ordinal.init)
        while rank <= end {
            let bucket = base.value[bucketOfRank: rank]
            let rankRaw = Int(bitPattern: rank)
            let lowered = Index<Element>(_unchecked: Ordinal(UInt(bitPattern: rankRaw - 1)))
            base.value[position: bucket] = lowered
            base.value[bucketOfRank: lowered] = bucket
            rank = Index<Element>(_unchecked: Ordinal(UInt(bitPattern: rankRaw + 1)))
        }
    }
}
