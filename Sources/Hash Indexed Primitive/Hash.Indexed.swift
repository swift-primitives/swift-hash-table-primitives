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

public import Buffer_Protocol_Primitives
public import Hash_Primitives
public import Hash_Table_Primitive
public import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Store_Protocol_Primitives

// MARK: - Hash.Indexed (the ordered hashed COLUMN: dense elements + the index engine)

extension Hash {
    /// The ordered hashed column — dense insertion-ordered elements plus a position-index engine.
    ///
    /// Elements live densely in insertion order; the hash side is the position-index
    /// engine (`Hash.Table`) whose planes are plain `Int`s. `Set<S>`/`Dictionary<S>`
    /// compose this column exactly as `Array`/`Queue` compose theirs.
    ///
    /// ## One generic parameter
    ///
    /// The bucket table is NOT a second column: it is derived state (positions into
    /// `elements`), concretely composed. `Dense` varies (the heap linear column today;
    /// inline/bounded dense variants later); the engine does not.
    ///
    /// ## Move-only; `Shared` wraps the COMPOSITE
    ///
    /// `Hash.Indexed` is unconditionally move-only. The CoW column is
    /// `Shared<E, Hash.Indexed<Dense>>` — one box around BOTH planes, one clone
    /// strategy (`clone()`: dense clone + the engine's seed-preserving plane copy).
    ///
    /// ## The seam, under the INDEXED DISCIPLINE (restricted domain)
    ///
    ///   • `subscript(slot:)` — any live dense slot; hash-changing writes RE-INDEX
    ///     the slot, so generic replacement stays coherent. The families expose no
    ///     element mutation (mutability ruling (a)); `Dictionary`'s value mutation
    ///     takes the no-change branch.
    ///   • `initialize(at: count)` — back-append + hash-index the new element.
    ///   • `move(at: count − 1)` — back-only removal (+ the bucket entry retires); the
    ///     general positional removal is the families' shift dance, not the seam's.
    public typealias Indexed = __HashIndexed
}

/// The hoisted backing type for ``Hash/Indexed`` — see that alias for the overview.
///
/// `Hash` is a non-generic namespace, but the hoist keeps the declaration symmetrical
/// with the family ADTs and keeps the alias canonical.
@frozen
public struct __HashIndexed<Dense: Store.`Protocol` & Buffer.`Protocol` & ~Copyable>: ~Copyable
where Dense.Count == Index_Primitives.Index<Dense.Element>.Count, Dense.Element: Hash.Key {

    /// The dense insertion-ordered element column.
    @usableFromInline
    package var elements: Dense

    /// The bucket position-index engine (hash, position) over POD planes.
    @usableFromInline
    package var indices: Hash.Table<Dense.Element>

    /// Composes an EMPTY column pair. (`elements` must be empty: the engine indexes
    /// every insertion from zero.)
    @inlinable
    public init(elements: consuming Dense, indices: consuming Hash.Table<Dense.Element>) {
        precondition(indices.isEmpty, "Hash.Indexed requires an empty index engine at composition")
        self.elements = elements
        self.indices = indices
    }

    /// Consumes the column, yielding the dense plane.
    @inlinable
    public consuming func take() -> Dense {
        elements
    }
}

extension __HashIndexed: Sendable where Dense: Sendable & ~Copyable, Dense.Element: Sendable {}

// MARK: - Store.Protocol (the seam witnesses; the indexed discipline)

extension __HashIndexed: Store.`Protocol` where Dense: ~Copyable {
    /// The element type stored in the dense column.
    public typealias Element = Dense.Element

    /// The number of elements the dense column can hold without reallocating.
    @inlinable
    public var capacity: Index_Primitives.Index<Dense.Element>.Count { elements.capacity }

    /// Live dense-slot access.
    ///
    /// A mutating write that changes the element's hash
    /// RE-INDEXES the slot (the old bucket entry retires; a fresh one is minted), so
    /// arbitrary replacement through the seam stays coherent. (The families expose no
    /// element mutation — mutability ruling (a); the lawful family path, `Dictionary`'s
    /// value mutation behind a hash-stable key, takes the cheap no-change branch.)
    @inlinable
    public subscript(slot: Index_Primitives.Index<Dense.Element>) -> Dense.Element {
        _read {
            yield elements[slot]
        }
        _modify {
            let oldHash = elements[slot].hashValue
            yield &elements[slot]
            let newHash = elements[slot].hashValue
            if oldHash != newHash {
                indices.remove(hashValue: oldHash, context: slot) { position, mutated in
                    position == mutated
                }
                indices.insert(_unchecked: (), position: slot, hashValue: newHash)
            }
        }
    }

    /// Back-append + hash-index (lawful ONLY at `slot == count`).
    @inlinable
    public mutating func initialize(at slot: Index_Primitives.Index<Dense.Element>, to element: consuming Dense.Element) {
        precondition(slot == elements.count.map(Ordinal.init), "indexed seam: initialize is lawful only at the back (slot == count)")
        let hashValue = element.hashValue
        elements.initialize(at: slot, to: element)
        indices.insert(_unchecked: (), position: slot, hashValue: hashValue)
    }

    /// Back-only removal (+ the bucket entry retires; no positions follow the last).
    @inlinable
    public mutating func move(at slot: Index_Primitives.Index<Dense.Element>) -> Dense.Element {
        let last: Index_Primitives.Index<Dense.Element> =
            elements.count.subtract.saturating(.one).map(Ordinal.init)
        precondition(slot == last, "indexed seam: move is lawful only at the back (slot == count − 1)")
        let element = elements.move(at: slot)
        indices.remove(hashValue: element.hashValue, context: slot) { position, removed in
            position == removed
        }
        return element
    }
}

// MARK: - Buffer.Protocol (the count surface)

extension __HashIndexed: Buffer.`Protocol` where Dense: ~Copyable {
    /// The number of elements in the dense column.
    @inlinable
    public var count: Index_Primitives.Index<Dense.Element>.Count { elements.count }
}
