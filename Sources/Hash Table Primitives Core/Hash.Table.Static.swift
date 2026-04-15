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

extension Hash.Table where Element: ~Copyable {

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
    public struct Static<let bucketCapacity: Int>: ~Copyable {
        // MARK: - Type Aliases (mirror parent for convenience)

        /// Bucket marker type (mirrors parent).
        public typealias Bucket = Hash.Table<Element>.Bucket

        // MARK: - Sentinels (mirror parent)

        /// Sentinel value indicating an empty bucket.
        @inlinable
        package static var empty: Int { Hash.Table<Element>.empty }

        /// Sentinel value indicating a deleted bucket (tombstone).
        @inlinable
        package static var deleted: Int { Hash.Table<Element>.deleted }

        /// Normalizes a hash value to avoid sentinel collisions.
        @inlinable
        package static func normalize(_ hashValue: Hash.Value) -> Int {
            Hash.Table<Element>.normalize(hashValue)
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
        var _occupied: Bucket.Index.Count

        /// Creates an empty inline hash table.
        ///
        /// - Precondition: `bucketCapacity` must be a power of two.
        @inlinable
        public init() {
            precondition(
                bucketCapacity > 0 && (bucketCapacity & (bucketCapacity - 1)) == 0,
                "bucketCapacity must be a power of two"
            )
            _hashes = .init(repeating: Hash.Table<Element>.empty)
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
        package func bucket(for hash: Int) -> Bucket.Index {
            let bucketOrd = Ordinal(UInt(bitPattern: hash)) % Cardinal(UInt(bucketCapacity))
            return Bucket.Index(__unchecked: (), bucketOrd)
        }

        /// Computes the next bucket in the linear probe sequence.
        ///
        /// Uses cyclic arithmetic (Z_{bucketCapacity}) for wrap-around.
        @inlinable
        package func bucket(after current: Bucket.Index) -> Bucket.Index {
            Bucket.Index.Modular.successor(
                of: current,
                capacity: Bucket.Index.Count(Cardinal(UInt(bucketCapacity)))
            )
        }

        // MARK: - Bucket Iteration

        /// Iterates over all bucket indices.
        @inlinable
        static func forEachBucket(_ body: (Bucket.Index) -> Void) {
            var bucket: Bucket.Index = .zero
            let cap = Bucket.Index.Count(Cardinal(UInt(bucketCapacity)))
            while bucket < cap {
                body(bucket)
                bucket += .one
            }
        }

        // MARK: - Typed InlineArray Access

        /// Reads the hash stored at the given bucket.
        @inlinable
        func readHash(at bucket: Bucket.Index) -> Int {
            _hashes[bucket]
        }

        /// Writes a hash value at the given bucket.
        @inlinable
        mutating func writeHash(at bucket: Bucket.Index, value: Int) {
            _hashes[bucket] = value
        }

        /// Reads the element position stored at the given bucket.
        ///
        /// Positions are bounded by `bucketCapacity` — the invariant is
        /// maintained by `writePosition` which only accepts bounded values.
        @inlinable
        func readPosition(at bucket: Bucket.Index) -> Index<Element>.Bounded<bucketCapacity> {
            let ordinal = Ordinal(UInt(bitPattern: _positions[bucket]))
            let finite: Ordinal.Finite<bucketCapacity> = .init(__unchecked: (), ordinal)
            return .init(__unchecked: (), finite)
        }

        /// Writes an element position at the given bucket.
        @inlinable
        mutating func writePosition(at bucket: Bucket.Index, value: Index<Element>.Bounded<bucketCapacity>) {
            _positions[bucket] = Int(bitPattern: value.rawValue.ordinal)
        }
    }
}

// MARK: - Conditional Conformances

extension Hash.Table.Static: Copyable where Element: Copyable {}
// WHY: Category D — structural Sendable workaround (SP-3).
// WHY: `Hash.Table.Static` stores only `InlineArray<bucketCapacity, Int>` fields
// WHY: and typed counts — all pure inline value bytes with no heap allocation.
// WHY: The `~Copyable` trait is inherited from the parent extension scope, not
// WHY: from owning a resource. The `<let bucketCapacity: Int>` value-generic and
// WHY: phantom `Element: ~Copyable` parameter both block structural Sendable
// WHY: inference. No caller invariant to uphold.
// WHEN TO REMOVE: When compiler gains structural Sendable inference through
// WHEN TO REMOVE: value-generic parameters and phantom type parameters.
// TRACKING: unsafe-audit-findings.md Category D SP-3.
extension Hash.Table.Static: @unchecked Sendable where Element: Sendable {}
