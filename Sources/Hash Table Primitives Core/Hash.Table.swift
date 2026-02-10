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
public import Ordinal_Primitives
public import Cardinal_Primitives
public import Cyclic_Index_Primitives
public import Finite_Primitives
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

        // MARK: - Nested Types

        /// Marker type for bucket indices in hash table storage.
        public struct Bucket: ~Copyable {}

        /// Typed index into the bucket array.
        public typealias BucketIndex = Index<Bucket>

        /// Tag type for bucket operations.
        public enum BucketOps {}

        /// Tag type for forEach operations.
        public enum ForEach {}

        /// Tag type for remove operations.
        public enum Remove {}

        /// Tag type for position update operations.
        public enum Positions {}

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

        // MARK: - Inline (Fixed-Capacity, Inline Storage)

        /// A fixed-capacity hash table with inline storage.
        ///
        /// `Hash.Table.Static` stores hash-position pairs directly in the struct,
        /// avoiding heap allocation. Use for small, bounded collections where
        /// O(1) lookup is needed without heap overhead.
        ///
        /// ## Bucket Capacity
        ///
        /// The `bucketCapacity` parameter specifies the number of hash buckets.
        /// MUST be a power of two (8, 16, 32, 64, ...).
        ///
        /// Effective element capacity is approximately 70% of bucket count:
        ///
        /// | Buckets | Max elements |
        /// |---------|--------------|
        /// | 8       | ~5           |
        /// | 16      | ~11          |
        /// | 32      | ~22          |
        /// | 64      | ~44          |
        ///
        /// ## Memory Layout
        ///
        /// Size: `bucketCapacity × 16 + ~32` bytes (hashes + positions + header).
        ///
        /// - Note: This type is declared inside `Hash.Table` (not in an extension) due to a
        ///   Swift compiler bug where nested types with value generic parameters declared
        ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
        public struct Static<let bucketCapacity: Int>: ~Copyable {
            // MARK: - Type Aliases (mirror parent for convenience)

            /// Bucket marker type (mirrors parent).
            public typealias Bucket = Table.Bucket

            /// Typed bucket index (mirrors parent).
            public typealias BucketIndex = Table.BucketIndex

            // MARK: - Sentinels (mirror parent)

            /// Sentinel value indicating an empty bucket.
            @inlinable
            public static var empty: Int { Table.empty }

            /// Sentinel value indicating a deleted bucket (tombstone).
            @inlinable
            public static var deleted: Int { Table.deleted }

            /// Normalizes a hash value to avoid sentinel collisions.
            @inlinable
            public static func normalize(_ hashValue: Hash.Value) -> Int {
                Table.normalize(hashValue)
            }

            // MARK: - Storage

            /// Hash values for each bucket. 0 = empty, Int.min = deleted.
            @usableFromInline
            var _hashes: InlineArray<bucketCapacity, Int>

            /// Element positions for each bucket.
            @usableFromInline
            var _positions: InlineArray<bucketCapacity, Int>

            /// Number of active elements.
            @usableFromInline
            var _count: Index<Element>.Count

            /// Number of occupied buckets (including deleted).
            @usableFromInline
            var _occupied: BucketIndex.Count

            /// Creates an empty inline hash table.
            ///
            /// - Precondition: `bucketCapacity` must be a power of two.
            @inlinable
            public init() {
                precondition(
                    bucketCapacity > 0 && (bucketCapacity & (bucketCapacity - 1)) == 0,
                    "bucketCapacity must be a power of two"
                )
                _hashes = .init(repeating: Table.empty)
                _positions = .init(repeating: 0)
                _count = .zero
                _occupied = .zero
            }

            // MARK: - Internal Bucket Access

            /// Computes the initial bucket index for a normalized hash.
            ///
            /// Maps the hash value into the cyclic bucket space [0, bucketCapacity)
            /// using unsigned modular reduction.
            @inlinable
            package func bucket(for hash: Int) -> BucketIndex {
                let bucketOrd = Ordinal(UInt(bitPattern: hash)) % Cardinal(UInt(bucketCapacity))
                return BucketIndex(__unchecked: (), bucketOrd)
            }

            /// Computes the next bucket in the linear probe sequence.
            ///
            /// Uses cyclic arithmetic (Z_{bucketCapacity}) for wrap-around.
            @inlinable
            package func bucket(after current: BucketIndex) -> BucketIndex {
                BucketIndex.Modular.successor(
                    of: current,
                    capacity: BucketIndex.Count(Cardinal(UInt(bucketCapacity)))
                )
            }

            // MARK: - Bucket Iteration

            /// Iterates over all bucket indices.
            @inlinable
            static func forEachBucketIndex(_ body: (BucketIndex) -> Void) {
                var bucket: BucketIndex = .zero
                let cap = BucketIndex.Count(Cardinal(UInt(bucketCapacity)))
                while bucket < cap {
                    body(bucket)
                    bucket += .one
                }
            }

            // MARK: - Typed InlineArray Access

            /// Reads the hash stored at the given bucket.
            @inlinable
            func readHash(at bucket: BucketIndex) -> Int {
                _hashes[Int(bitPattern: bucket.position)]
            }

            /// Writes a hash value at the given bucket.
            @inlinable
            mutating func writeHash(at bucket: BucketIndex, value: Int) {
                _hashes[Int(bitPattern: bucket.position)] = value
            }

            /// Reads the element position stored at the given bucket.
            ///
            /// Positions are bounded by `bucketCapacity` — the invariant is
            /// maintained by `writePosition` which only accepts bounded values.
            @inlinable
            func readPosition(at bucket: BucketIndex) -> Index<Element>.Bounded<bucketCapacity> {
                let ordinal = Ordinal(UInt(bitPattern: _positions[Int(bitPattern: bucket.position)]))
                let finite: Ordinal.Finite<bucketCapacity> = .init(__unchecked: (), ordinal)
                return .init(__unchecked: (), finite)
            }

            /// Writes an element position at the given bucket.
            @inlinable
            mutating func writePosition(at bucket: BucketIndex, value: Index<Element>.Bounded<bucketCapacity>) {
                _positions[Int(bitPattern: bucket.position)] = Int(bitPattern: value.rawValue.ordinal)
            }
        }
    }
}

// MARK: - Conditional Conformances (must be same file)

extension Hash.Table: Copyable where Element: Copyable {}
extension Hash.Table: @unchecked Sendable where Element: ~Copyable {}

extension Hash.Table.Static: Copyable where Element: Copyable {}
extension Hash.Table.Static: @unchecked Sendable where Element: Sendable {}
