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
public import Buffer_Primitive
public import Buffer_Slots_Primitive
public import Buffer_Slots_Primitives
import Cardinal_Primitives
public import Cyclic_Index_Primitives
public import Hash_Primitives
public import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
internal import Ordinal_Primitives
public import Ordinal_Primitives_Standard_Library_Integration
internal import Property_Primitives
public import Storage_Contiguous_Primitives
public import Storage_Primitive
public import Store_Primitive
public import Store_Split_Primitives

extension Hash.Table.Remove where Element: ~Copyable {
    /// The mutable accessor view for removal operations.
    public typealias View = Property<Hash.Table<Element>.Remove, Hash.Table<Element>>.Inout.Typed<Element>
}

// MARK: - Removal (BACKWARD-SHIFT chain repair — tombstone-free)
//
// The ADT-families reshape adopted the upstream consensus (stdlib `HashTable.swift:467–508`
// "If we've put a hole in a chain of contiguous elements, some element after the hole may
// belong where the new hole is"; swift-collections `_HTable+Removal.swift` "Our hash table
// does not have tombstones"): emptying a bucket walks the chain after it and relocates any
// entry whose IDEAL bucket lies cyclically at-or-before the hole, so probe chains stay
// contiguous and `empty` remains the only sentinel. The former `deleted` sentinel and the
// `rehash()` compaction pass are gone with it.

extension Hash.Table where Element: ~Copyable {
    /// Cyclic distance from `from` to `to` (power-of-two capacity mask).
    @inlinable
    package func _distance(from: Bucket.Index, to: Bucket.Index) -> UInt {
        let mask = UInt(bitPattern: Int(bitPattern: bucketCapacity)) &- 1
        let rawTo = UInt(bitPattern: Int(bitPattern: to))
        let rawFrom = UInt(bitPattern: Int(bitPattern: from))
        return (rawTo &- rawFrom) & mask
    }

    /// Repairs the probe chain after `hole` was emptied: relocates displaced entries
    /// backward into the hole until the chain's end.
    @inlinable
    package mutating func _shiftChain(into emptied: Bucket.Index) {
        var hole = emptied
        var current = Bucket.Index.Modular.successor(of: hole, capacity: bucketCapacity)
        while self[hash: current] != Self.empty {
            let ideal = Self.bucket(for: self[hash: current], seed: _seed, capacity: bucketCapacity)
            // The entry may move back iff the hole lies within its displacement span:
            // distance(ideal → hole) < distance(ideal → current).
            if _distance(from: ideal, to: hole) < _distance(from: ideal, to: current) {
                self[hash: hole] = self[hash: current]
                self[position: hole] = self[position: current]
                self[bucketOfRank: self[position: hole]] = hole
                self[hash: current] = Self.empty
                hole = current
            }
            current = Bucket.Index.Modular.successor(of: current, capacity: bucketCapacity)
        }
    }

    /// Removes an element from the hash table.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to remove.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the element to remove.
    /// - Returns: The typed position that was removed, or `nil` if not found.
    @inlinable
    @discardableResult
    public mutating func remove(
        hashValue: Hash.Value,
        equals: (Index<Element>) -> Bool
    ) -> Index<Element>? {
        guard let index = index(forHash: hashValue, equals: equals) else {
            return nil
        }

        let position = self[position: index]
        self[hash: index] = Self.empty
        _count = _count.subtract.saturating(.one)
        _shiftChain(into: index)
        return position
    }

    /// Removes an element from the hash table, passing a context value
    /// through to the equality closure instead of capturing it.
    ///
    /// This overload avoids capturing the search element in the closure,
    /// which is required when the element is `borrowing` and `~Copyable`.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to remove.
    ///   - context: A value passed through to `equals` on each probe.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the context.
    /// - Returns: The typed position that was removed, or `nil` if not found.
    @inlinable
    @discardableResult
    public mutating func remove<Context: ~Copyable>(
        hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Index<Element>, borrowing Context) -> Bool
    ) -> Index<Element>? {
        let hash = Self.normalize(hashValue)
        let capacity = bucketCapacity
        var currentBucket = Self.bucket(for: hash, seed: _seed, capacity: capacity)
        var probes: Index<Bucket>.Count = .zero

        while probes < capacity {
            let storedHash = self[hash: currentBucket]

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = self[position: currentBucket]
                if equals(position, context) {
                    self[hash: currentBucket] = Self.empty
                    _count = _count.subtract.saturating(.one)
                    _shiftChain(into: currentBucket)
                    return position
                }
            }

            currentBucket = Bucket.Index.Modular.successor(of: currentBucket, capacity: capacity)
            probes += .one
        }

        return nil
    }

    /// Removes the element at a specific bucket.
    ///
    /// - Parameter bucketIdx: The bucket index to remove.
    @inlinable
    public mutating func remove(at bucketIdx: Bucket.Index) {
        precondition(self[hash: bucketIdx] != Self.empty)
        self[hash: bucketIdx] = Self.empty
        _count = _count.subtract.saturating(.one)
        _shiftChain(into: bucketIdx)
    }

    /// Access remove operations.
    @inlinable
    public var remove: Remove.View {
        mutating _read {
            yield.init(&self)
        }
        mutating _modify {
            var view: Remove.View = .init(&self)
            yield &view
        }
    }
}

extension Property.Inout.Typed
where Tag == Hash.Table<Element>.Remove, Base == Hash.Table<Element>, Element: ~Copyable {
    /// Removes all elements.
    @inlinable
    public mutating func all(keepingCapacity: Bool = false) {
        if keepingCapacity {
            base.value._buffer.fill(metadata: Hash.Table<Element>.empty)
            base.value._buffer.fill(payload: 0)
            base.value._count = .zero
            // The rank plane needs no work: every rank dies with the count,
            // and stale plane entries are never read.
        } else {
            let hashCapacity = Hash.Table<Element>.bucketCapacity(for: .zero)
            var buffer = Buffer<Store.Split<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>, Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>>.Slots(
                capacity: hashCapacity.retag(Int.self),
                metadataInitial: Hash.Table<Element>.empty
            )
            buffer.fill(payload: 0)
            base.value._buffer = buffer
            base.value._rankToBucket = Hash.Table<Element>.makeRankPlane(bucketCapacity: hashCapacity)
            base.value._count = .zero
        }
    }
}
