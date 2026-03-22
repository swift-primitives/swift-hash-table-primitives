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
internal import Ordinal_Primitives
public import Cardinal_Primitives
internal import Cyclic_Index_Primitives
internal import Finite_Primitives
public import Buffer_Slots_Primitives

extension Hash {
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
    /// ## Conditional Copyable
    ///
    /// `Hash.Table` is conditionally `Copyable` when `Element` is `Copyable`.
    /// This enables containers using `Hash.Table` to also be conditionally Copyable.
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
    public struct Table<Element: ~Copyable>: ~Copyable {

        // MARK: - Stored Properties

        @usableFromInline
        package var _count: Index<Element>.Count

        @usableFromInline
        package var _occupied: Index<Bucket>.Count

        @usableFromInline
        package var _buffer: Buffer<Int>.Slots<Int>

        // MARK: - Sentinels

        /// Sentinel value indicating an empty bucket.
        @inlinable
        public static var empty: Int { 0 }

        /// Sentinel value indicating a deleted bucket.
        @inlinable
        public static var deleted: Int { Int.min }

        // MARK: - Canonical Initializer

        /// Creates an empty hash table with the specified initial capacity.
        ///
        /// - Parameter minimumCapacity: The minimum number of elements the
        ///   hash table should be able to store without rehashing.
        @inlinable
        public init(minimumCapacity: Index<Element>.Count = .zero) {
            let hashCapacity = Self.bucketCapacity(for: minimumCapacity)
            _count = .zero
            _occupied = .zero
            let buffer = Buffer<Int>.Slots<Int>(
                capacity: hashCapacity.retag(Int.self),
                metadataInitial: Self.empty
            )
            buffer.fill(payload: 0)
            _buffer = buffer
        }

        // MARK: - Core Utilities (needed by init)

        /// Computes bucket capacity for a given minimum element capacity.
        ///
        /// Uses power-of-two sizing for fast modulo via bitmasking.
        /// Targets ~70% load factor.
        @inlinable
        public static func bucketCapacity(for minimumCapacity: Index<Element>.Count) -> Index<Bucket>.Count {
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

        /// Normalizes a hash value to avoid sentinel collisions.
        ///
        /// Maps `0` to `1` (since `0` is the empty sentinel).
        /// Maps `Int.min` to `1` (since `Int.min` is the deleted sentinel).
        @inlinable
        public static func normalize(_ hashValue: Hash.Value) -> Int {
            let raw = hashValue.rawValue
            let hash = raw == 0 ? 1 : raw
            return hash == Int.min ? 1 : hash
        }

    }
}

// MARK: - Conditional Conformances

extension Hash.Table: Copyable where Element: Copyable {}
extension Hash.Table: @unchecked Sendable where Element: Sendable {}
