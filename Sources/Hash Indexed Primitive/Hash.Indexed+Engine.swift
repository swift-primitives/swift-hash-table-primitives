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
import Buffer_Linear_Primitives
public import Buffer_Primitive
public import Hash_Primitives
public import Hash_Table_Primitive
public import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Contiguous_Primitives
public import Storage_Primitive

// MARK: - The coupled engine ops, pinned to the heap dense column ([MEM-COPY-018]:
// dense GROWTH cannot ride the seam, so the semantic surface pins — the Array+Columns
// pattern; new dense variants add their own pins)

extension __HashIndexed where Dense: ~Copyable {
    /// Creates an empty ordered hashed column over the heap dense plane.
    @inlinable
    public init<E: ~Copyable>(minimumCapacity: Index<E>.Count = .zero)
    where Dense == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        self.init(
            elements: Dense(minimumCapacity: minimumCapacity),
            indices: Hash.Table(minimumCapacity: minimumCapacity)
        )
    }

    /// Inserts a new member; returns `nil` on success, or hands the element BACK if an
    /// equal member is already present (move-only honesty: a rejected value is never
    /// silently destroyed).
    ///
    /// - Complexity: O(1) amortized
    @inlinable
    @discardableResult
    public mutating func insert<E: ~Copyable>(_ element: consuming E) -> E?
    where Dense == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        let hashValue = element.hashValue
        let duplicate = indices.position(forHash: hashValue, context: element) { position, candidate in
            elements[position] == candidate
        }
        if duplicate != nil {
            return element
        }
        let position: Index<E> = elements.count.map(Ordinal.init)
        elements.append(element)
        indices.insert(_unchecked: (), position: position, hashValue: hashValue)
        return nil
    }

    /// Whether an equal member is present.
    ///
    /// - Complexity: O(1) average
    @inlinable
    public func contains<E: ~Copyable>(_ element: borrowing E) -> Bool
    where Dense == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        position(of: element) != nil
    }

    /// The dense position of the equal member, if present.
    ///
    /// - Complexity: O(1) average
    @inlinable
    public func position<E: ~Copyable>(of element: borrowing E) -> Index<E>?
    where Dense == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        indices.position(forHash: element.hashValue, context: element) { position, candidate in
            elements[position] == candidate
        }
    }

    /// Removes the equal member, preserving insertion order (the dense shift dance).
    ///
    /// - Returns: The removed member, or `nil` if absent.
    /// - Complexity: O(n) from the removal point (order preservation)
    @inlinable
    public mutating func remove<E: ~Copyable>(_ element: borrowing E) -> E?
    where Dense == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        guard let position = position(of: element) else { return nil }

        // 1. Retire the bucket entry (by the STORED member's hash, before any shifts).
        let storedHash = elements[position].hashValue
        indices.remove(hashValue: storedHash, context: position) { candidate, removed in
            candidate == removed
        }

        // 2. The order-preserving dense shift (the Array.remove(at:) dance through the
        //    seam; the column's ledger keeps count honest).
        let end: Index<E> = elements.count.map(Ordinal.init)
        let removed = elements.move(at: position)
        var dst = position
        var src = dst.successor.saturating()
        while src < end {
            elements.initialize(at: dst, to: elements.move(at: src))
            dst = src
            src = src.successor.saturating()
        }

        // 3. Every position after the removal point shifted down by one.
        indices.positions.decrement(after: position)
        return removed
    }

    /// Removes all members.
    @inlinable
    public mutating func removeAll<E: ~Copyable>(keepingCapacity: Bool = true)
    where Dense == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        elements.removeAll(keepingCapacity: keepingCapacity)
        indices.remove.all(keepingCapacity: keepingCapacity)
    }

    /// Calls the closure for each member, in insertion order.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach(_ body: (borrowing Dense.Element) -> Void) {
        var slot: Index<Dense.Element> = .zero
        let end = elements.count.map(Ordinal.init)
        while slot < end {
            body(elements[slot])
            slot = slot.successor.saturating()
        }
    }
}

// MARK: - Explicit deep copy (the `Shared` clone strategy)

extension __HashIndexed where Dense: ~Copyable {
    /// Returns an independent copy: the dense plane's exact-fit-free clone + the
    /// engine's seed-and-layout-preserving plane copy (positions stay valid verbatim).
    ///
    /// - Complexity: O(`capacity`)
    @inlinable
    public func clone<E>() -> Self
    where Dense == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear, E: Copyable {
        var copy = Self(minimumCapacity: .zero)
        copy.elements = elements.clone()
        copy.indices = indices.clone()
        return copy
    }
}

// MARK: - Projected-key probing (the Dictionary door: lookups by a PROJECTION of the
// member — the key — without constructing a member; context-threading per the engine's
// own discipline)

extension __HashIndexed where Dense: ~Copyable {
    /// The dense position of the member matching `hashValue` + `equals`, if present.
    ///
    /// `equals` receives the CANDIDATE member and the threaded context (the projection
    /// being searched — e.g. a dictionary key); no member is constructed.
    ///
    /// - Complexity: O(1) average
    @inlinable
    public func position<E: ~Copyable, Context: ~Copyable>(
        matching hashValue: Hash.Value,
        context: borrowing Context,
        equals: (borrowing E, borrowing Context) -> Bool
    ) -> Index<E>?
    where Dense == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        indices.position(forHash: hashValue, context: context) { position, context in
            equals(elements[position], context)
        }
    }

    /// Removes the member matching `hashValue` + `equals`, preserving insertion order.
    ///
    /// - Returns: The removed member, or `nil` if absent.
    /// - Complexity: O(n) from the removal point (order preservation)
    @inlinable
    public mutating func remove<E: ~Copyable, Context: ~Copyable>(
        matching hashValue: Hash.Value,
        context: borrowing Context,
        equals: (borrowing E, borrowing Context) -> Bool
    ) -> E?
    where Dense == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear {
        guard let position = position(matching: hashValue, context: context, equals: equals) else {
            return nil
        }

        let storedHash = elements[position].hashValue
        indices.remove(hashValue: storedHash, context: position) { candidate, removed in
            candidate == removed
        }

        let end: Index<E> = elements.count.map(Ordinal.init)
        let removed = elements.move(at: position)
        var dst = position
        var src = dst.successor.saturating()
        while src < end {
            elements.initialize(at: dst, to: elements.move(at: src))
            dst = src
            src = src.successor.saturating()
        }

        indices.positions.decrement(after: position)
        return removed
    }
}
