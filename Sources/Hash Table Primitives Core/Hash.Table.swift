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
public import Pointer_Primitives
public import Ordinal_Primitives
public import Cardinal_Primitives

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

        /// Header for hash table storage.
        @usableFromInline
        package struct Header: Sendable {
            /// Number of active elements in the hash table.
            @usableFromInline
            package var count: Index<Element>.Count

            /// Number of occupied buckets (including deleted).
            @usableFromInline
            package var occupied: Index<Bucket>.Count

            /// Total number of buckets.
            @usableFromInline
            package var capacity: Index<Bucket>.Count

            @inlinable
            package init(capacity: Index<Bucket>.Count) {
                self.count = .zero
                self.occupied = .zero
                self.capacity = capacity
            }
        }

        /// Internal storage class using ManagedBuffer.
        /// Stores hashes and positions in a single allocation.
        /// Header contains (count, occupied, capacity).
        /// Elements are laid out as: [hashes...][positions...]
        @usableFromInline
        package final class Storage: ManagedBuffer<Header, Int> {
            deinit {
                // ManagedBuffer handles deallocation automatically
            }

            /// Creates storage with the specified bucket capacity.
            @usableFromInline
            package static func create(capacity: Index<Bucket>.Count) -> Storage {
                let cap = Int(capacity.rawValue.rawValue)
                let storage = Storage.create(minimumCapacity: cap * 2) { _ in
                    Header(capacity: capacity)
                }
                // Initialize all slots to empty (0)
                _ = unsafe storage.withUnsafeMutablePointerToElements { elements in
                    unsafe elements.initialize(repeating: Table.empty, count: cap * 2)
                }
                return unsafe unsafeDowncast(storage, to: Storage.self)
            }

            // MARK: - Typed Pointer Access

            /// Pointer to hash values array.
            @usableFromInline
            package var hashesPointer: Pointer<Int>.Mutable {
                unsafe withUnsafeMutablePointerToElements {
                    unsafe Pointer<Int>.Mutable($0)
                }
            }

            /// Pointer to positions array.
            @usableFromInline
            package var positionsPointer: Pointer<Int>.Mutable {
                let cap = Int(header.capacity.rawValue.rawValue)
                return unsafe withUnsafeMutablePointerToElements {
                    unsafe Pointer<Int>.Mutable($0 + cap)
                }
            }

            // MARK: - Typed Read/Write

            /// Reads hash at bucket index.
            @usableFromInline
            package func readHash(at bucket: BucketIndex) -> Int {
                let idx = Index<Int>(__unchecked: (), bucket.position)
                return hashesPointer[idx]
            }

            /// Reads position at bucket index, returning typed Index<Element>.
            @usableFromInline
            package func readPosition(at bucket: BucketIndex) -> Index<Element> {
                let idx = Index<Int>(__unchecked: (), bucket.position)
                let raw = positionsPointer[idx]
                return Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: raw)))
            }

            /// Writes hash at bucket index.
            @usableFromInline
            package func writeHash(at bucket: BucketIndex, value: Int) {
                let idx = Index<Int>(__unchecked: (), bucket.position)
                hashesPointer[idx] = value
            }

            /// Writes position at bucket index.
            @usableFromInline
            package func writePosition(at bucket: BucketIndex, value: Index<Element>) {
                let idx = Index<Int>(__unchecked: (), bucket.position)
                positionsPointer[idx] = Int(bitPattern: value.position.rawValue)
            }
        }

        // MARK: - Stored Properties

        @usableFromInline
        package var _storage: Storage

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
            _storage = Storage.create(capacity: hashCapacity)
        }

        // MARK: - Core Utilities (needed by init)

        /// Computes bucket capacity for a given minimum element capacity.
        ///
        /// Uses power-of-two sizing for fast modulo via bitmasking.
        /// Targets ~70% load factor.
        @inlinable
        public static func bucketCapacity(for minimumCapacity: Index<Element>.Count) -> Index<Bucket>.Count {
            let minCap = Int(minimumCapacity.rawValue.rawValue)
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
        public static func normalize(_ hashValue: Int) -> Int {
            let hash = hashValue == 0 ? 1 : hashValue
            return hash == Int.min ? 1 : hash
        }
    }
}

// MARK: - Conditional Conformances (must be same file)

extension Hash.Table: Copyable where Element: Copyable {}
extension Hash.Table: @unchecked Sendable where Element: ~Copyable {}
