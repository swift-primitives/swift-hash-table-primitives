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

public import Affine_Primitives_Standard_Library_Integration
public import Buffer_Linear_Primitive
public import Buffer_Primitive
public import Buffer_Slots_Primitive
import Cardinal_Primitives
internal import Cyclic_Index_Primitives
internal import Finite_Primitives
import Hash_Primitives
public import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
internal import Ordinal_Primitives
public import Storage_Contiguous_Primitives
public import Storage_Primitive
public import Store_Primitive
public import Store_Split_Primitives

extension Hash {
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    /// A hash table mapping elements to their typed indices in external storage.
    ///
    /// `Hash.Table<Element>` provides O(1) average-case lookup for element positions,
    /// supporting `~Copyable` elements through `Hash.Protocol`. Positions are typed
    /// using `Index_Primitives.Index<Element>` for compile-time safety.
    ///
    /// ## Design
    ///
    /// This is an open-addressed hash table using linear probing. It stores
    /// `(hashValue, position)` pairs, where `position` is a typed `Index<Element>`
    /// referring to an index in external storage (e.g., `Set.Ordered`'s element array).
    ///
    /// ## Type Safety
    ///
    /// The generic parameter `Element` provides phantom-type safety:
    /// - `Hash.Table<Int>` positions cannot be mixed with `Hash.Table<String>` positions
    /// - Compile-time prevention of index confusion between different collections
    ///
    /// Bucket indices use a separate phantom type `Bucket` to prevent confusion
    /// between bucket indices and element positions.
    ///
    /// ## Move-only (R-1)
    ///
    /// `Hash.Table` is unconditionally move-only (the pre-R-1 conditional Copyable +
    /// `ensureUnique` dissolved at the ADT-families reshape): value semantics enter via
    /// `Shared` wrapping the COMPOSITE (`Shared<E, Hash.Indexed<Dense>>`), never the
    /// engine. `clone()` is the explicit deep copy the composite's clone strategy uses —
    /// seed-and-layout-preserving (no rehash), the stdlib `copy()` discipline.
    ///
    /// ## Tombstone-free (the archaeology amendment, 2026-06-10)
    ///
    /// Removal repairs probe chains by BACKWARD SHIFT (the upstream consensus — stdlib
    /// and swift-collections both reject tombstones), so `empty` is the only sentinel,
    /// occupied == count always, and no compaction pass exists.
    ///
    /// ## Seeding
    ///
    /// A per-instance `_seed` is XOR-mixed into bucket selection (probe order is
    /// per-instance), REGENERATED on growth (the stdlib quadratic-copy defense), and
    /// PRESERVED by `clone()` (no rehash on copy). Recorded gaps vs stdlib: the seed
    /// mixes at the engine (the institute `Hash.Protocol` has no seeded entry point
    /// yet), and there is no deterministic-hashing environment toggle.
    ///
    /// ## Usage with Set.Ordered
    ///
    /// ```swift
    /// struct OrderedSet<Element: ~Copyable & Hash.Protocol>: ~Copyable {
    ///     var elements: Array<Element>.Bounded
    ///     var indices: Hash.Table<Element>
    ///
    ///     mutating func contains(_ element: borrowing Element) -> Bool {
    ///         indices.position(
    ///             forHash: element.hashValue,
    ///             equals: { idx in elements.withElement(at: idx) { $0 == element } }
    ///         ) != nil
    ///     }
    /// }
    /// ```
    @safe
    @frozen
    public struct Table<Element: ~Copyable>: ~Copyable {

        // MARK: - Stored Properties

        @usableFromInline
        package var _count: Index<Element>.Count

        /// Per-instance probe seed (see `## Seeding`).
        @usableFromInline
        package var _seed: Int

        @usableFromInline
        package var _buffer: Buffer<Store.Split<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>, Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>>.Slots

        /// The rank→bucket back-pointer plane (B-7): for every LIVE rank,
        /// `_rankToBucket[rank]` names the bucket holding that rank's entry.
        ///
        /// Maintained at the three placement points (insert, chain-repair
        /// relocation, growth re-probe); entries above the live count are
        /// stale by construction and never read. Sized to `bucketCapacity`
        /// (ranks < count ≤ ~0.7 × capacity) and zero-filled — +8 bytes per
        /// BUCKET, banked as arc-5 SoA-round layout input. It turns the
        /// post-removal position fixup from the Θ(bucketCapacity) sweep into
        /// the documented O(n − rank) walk (`decrement(after:)`).
        @usableFromInline
        package var _rankToBucket: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Linear

        // MARK: - Sentinels

        /// Sentinel value indicating an empty bucket (the ONLY sentinel — removal
        /// repairs chains by backward shift; no tombstones exist).
        @inlinable
        package static var empty: Int { 0 }

        // MARK: - Canonical Initializer

        /// Creates an empty hash table with the specified initial capacity.
        ///
        /// - Parameter minimumCapacity: The minimum number of elements the
        ///   hash table should be able to store without rehashing.
        @inlinable
        public init(minimumCapacity: Index<Element>.Count = .zero) {
            let hashCapacity = Self.bucketCapacity(for: minimumCapacity)
            _count = .zero
            _seed = Self.makeSeed()
            var buffer = Buffer<Store.Split<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>, Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>>.Slots(
                capacity: hashCapacity.retag(Int.self),
                metadataInitial: Self.empty
            )
            buffer.fill(payload: 0)
            _buffer = buffer
            _rankToBucket = Self.makeRankPlane(bucketCapacity: hashCapacity)
        }

        /// A zero-filled rank→bucket plane covering `bucketCapacity` ranks.
        @inlinable
        package static func makeRankPlane(
            bucketCapacity: Index<Bucket>.Count
        ) -> Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Linear {
            var plane = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Linear(
                minimumCapacity: bucketCapacity.retag(Int.self)
            )
            // Bulk zero-fill through the OutputSpan door — the per-element
            // seam append paid ~5 ns/bucket of growth-check + ledger traffic
            // (the init.sized regression caught at the W2 maintenance gate).
            plane.append(addingCapacity: bucketCapacity.retag(Int.self)) { (span: inout Swift.OutputSpan<Int>) in
                while !span.isFull {
                    span.append(0)
                }
            }
            return plane
        }

        // MARK: - Core Utilities (needed by init)

        /// Computes bucket capacity for a given minimum element capacity.
        ///
        /// Uses power-of-two sizing for fast modulo via bitmasking.
        /// Targets ~70% load factor.
        @inlinable
        package static func bucketCapacity(for minimumCapacity: Index<Element>.Count) -> Index<Bucket>.Count {
            let minCap = Int(bitPattern: minimumCapacity)
            guard minCap > 0 else {
                return Index<Bucket>.Count(Cardinal(8))
            }
            // Target ~70% load factor
            let needed = max(8, (minCap * 10) / 7)
            // Round up to next power of two
            let powerOfTwo = 1 << (Int.bitWidth - (needed - 1).leadingZeroBitCount)
            return Index<Bucket>.Count(Cardinal(UInt(powerOfTwo)))
        }

        /// Normalizes a hash value to avoid the sentinel: maps `0` to `1`
        /// (`0` is the empty sentinel; backward-shift removal needs no other).
        @inlinable
        package static func normalize(_ hashValue: Hash.Value) -> Int {
            let raw = hashValue.underlying
            return raw == 0 ? 1 : raw
        }

        /// A fresh per-instance probe seed.
        @inlinable
        package static func makeSeed() -> Int {
            var generator = SystemRandomNumberGenerator()
            return Int(bitPattern: UInt(truncatingIfNeeded: generator.next() as UInt64))
        }

    }
}

// MARK: - Conditional Conformances
/// Sendable conformance for `Hash.Table`.
///
/// ## Safety Invariant
///
/// `Hash.Table` is `~Copyable` and owns a heap-allocated `Buffer.Slots`
/// backing store. Single ownership is enforced by the type system; cross-thread
/// transfer via move relinquishes the sender's access, preventing data races
/// by construction.
///
/// ## Intended Use
///
/// - Transferring a prepared hash table to a worker thread.
/// - Handing off a hash table across actors as a one-shot ownership transfer.
/// - Actor-owned hash tables constructed outside the actor and passed in at init.
///
/// ## Non-Goals
///
/// - Does not support concurrent access from multiple threads.
/// - Ownership is single-owner; transfer is one-shot via `consuming` parameter.
/// - This conformance does not make arbitrary sharing safe — `~Copyable`
///   prevents aliasing at compile time.
extension Hash.Table: @unsafe @unchecked Sendable where Element: Sendable {}
