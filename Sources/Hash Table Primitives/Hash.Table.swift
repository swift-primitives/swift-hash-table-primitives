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
    ///     func contains(_ element: borrowing Element) -> Bool {
    ///         indices.position(
    ///             forHash: element.hashValue,
    ///             equals: { idx in elements.withElement(at: idx) { $0 == element } }
    ///         ) != nil
    ///     }
    /// }
    /// ```
    @safe
    public struct Table<Element: ~Copyable>: ~Copyable {

        // MARK: - Storage Class

        /// Internal storage class using ManagedBuffer.
        /// Stores hashes and positions in a single allocation.
        /// Header contains (count, occupied, hashCapacity).
        /// Elements are laid out as: [hashes...][positions...]
        @usableFromInline
        final class Storage: ManagedBuffer<(count: Int, occupied: Int, hashCapacity: Int), Int> {

            /// Creates storage with the specified hash capacity.
            @usableFromInline
            static func create(hashCapacity: Int) -> Storage {
                // Allocate space for hashes + positions
                let storage = Storage.create(minimumCapacity: hashCapacity * 2) { _ in
                    (count: 0, occupied: 0, hashCapacity: hashCapacity)
                }
                // Initialize all slots to empty (0)
                _ = unsafe storage.withUnsafeMutablePointerToElements { elements in
                    unsafe elements.initialize(repeating: Table.empty, count: hashCapacity * 2)
                }
                return unsafe unsafeDowncast(storage, to: Storage.self)
            }

            deinit {
                // ManagedBuffer handles deallocation automatically
            }

            /// Pointer to hash values.
            @usableFromInline
            var _hashesPointer: UnsafeMutablePointer<Int> {
                unsafe withUnsafeMutablePointerToElements { unsafe $0 }
            }

            /// Pointer to position values.
            @usableFromInline
            var _positionsPointer: UnsafeMutablePointer<Int> {
                let hashCapacity = header.hashCapacity
                return unsafe withUnsafeMutablePointerToElements { unsafe $0 + hashCapacity }
            }

            /// Reads hash at bucket index.
            @usableFromInline
            func _readHash(at bucket: Int) -> Int {
                unsafe withUnsafeMutablePointerToElements { unsafe $0[bucket] }
            }

            /// Reads position at bucket index.
            @usableFromInline
            func _readPosition(at bucket: Int) -> Int {
                let hashCapacity = header.hashCapacity
                return unsafe withUnsafeMutablePointerToElements { unsafe $0[hashCapacity + bucket] }
            }

            /// Writes hash at bucket index.
            @usableFromInline
            func _writeHash(at bucket: Int, value: Int) {
                unsafe withUnsafeMutablePointerToElements { unsafe $0[bucket] = value }
            }

            /// Writes position at bucket index.
            @usableFromInline
            func _writePosition(at bucket: Int, value: Int) {
                let hashCapacity = header.hashCapacity
                unsafe withUnsafeMutablePointerToElements { unsafe $0[hashCapacity + bucket] = value }
            }
        }

        @usableFromInline
        var _storage: Storage

        // NO deinit - Storage class handles cleanup via ManagedBuffer

        // MARK: - Sentinel Values

        /// Sentinel value indicating an empty bucket.
        @inlinable
        public static var empty: Int { 0 }

        /// Sentinel value indicating a deleted bucket.
        @inlinable
        public static var deleted: Int { Int.min }

        // MARK: - Initialization

        /// Creates an empty hash index with the specified initial capacity.
        ///
        /// - Parameter minimumCapacity: The minimum number of elements the
        ///   hash table should be able to store without rehashing.
        @inlinable
        public init(minimumCapacity: Int = 0) {
            let hashCapacity = Self.capacity(for: minimumCapacity)
            _storage = Storage.create(hashCapacity: hashCapacity)
        }

        /// Computes the actual capacity for a given minimum capacity.
        /// Uses power-of-two sizing for fast modulo via bitmasking.
        @inlinable
        static func capacity(for minimumCapacity: Int) -> Int {
            guard minimumCapacity > 0 else { return 8 }
            // Target ~70% load factor
            let needed = max(8, (minimumCapacity * 10) / 7)
            // Round up to next power of two
            return 1 << (Int.bitWidth - (needed - 1).leadingZeroBitCount)
        }

        // MARK: - Properties

        /// The number of elements in the hash table.
        @inlinable
        public var count: Int { _storage.header.count }

        /// Whether the hash table is empty.
        @inlinable
        public var isEmpty: Bool { _storage.header.count == 0 }

        /// The current capacity of the hash table.
        @inlinable
        public var capacity: Int { _storage.header.hashCapacity }

        // MARK: - Lookup

        /// Finds the position for an element with the given hash value.
        ///
        /// - Parameters:
        ///   - hashValue: The hash value of the element to find.
        ///   - equals: A closure that checks if the element at a given position
        ///     matches the search element. Called for hash collisions.
        /// - Returns: The typed position in external storage if found, or `nil`.
        @inlinable
        public func position(
            forHash hashValue: Int,
            equals: (Index_Primitives.Index<Element>) -> Bool
        ) -> Index_Primitives.Index<Element>? {
            let hash = Self.normalize(hashValue)
            let hashCapacity = _storage.header.hashCapacity
            var bucket = Self.bucket(for: hash, capacity: hashCapacity)

            while true {
                let storedHash = _storage._readHash(at: bucket)

                if storedHash == Self.empty {
                    return nil
                }

                if storedHash == hash {
                    let rawPosition = _storage._readPosition(at: bucket)
                    let position = Index_Primitives.Index<Element>(__unchecked: (), position: rawPosition)
                    if equals(position) {
                        return position
                    }
                }

                bucket = Self.nextBucket(bucket, capacity: hashCapacity)
            }
        }

        /// Finds the bucket index for an element with the given hash value.
        ///
        /// - Parameters:
        ///   - hashValue: The hash value of the element to find.
        ///   - equals: A closure that checks if the element at a given position
        ///     matches the search element.
        /// - Returns: The bucket index if found, or `nil`.
        @inlinable
        public func bucket(
            forHash hashValue: Int,
            equals: (Index_Primitives.Index<Element>) -> Bool
        ) -> Int? {
            let hash = Self.normalize(hashValue)
            let hashCapacity = _storage.header.hashCapacity
            var bucket = Self.bucket(for: hash, capacity: hashCapacity)

            while true {
                let storedHash = _storage._readHash(at: bucket)

                if storedHash == Self.empty {
                    return nil
                }

                if storedHash == hash {
                    let rawPosition = _storage._readPosition(at: bucket)
                    let position = Index_Primitives.Index<Element>(__unchecked: (), position: rawPosition)
                    if equals(position) {
                        return bucket
                    }
                }

                bucket = Self.nextBucket(bucket, capacity: hashCapacity)
            }
        }

        // MARK: - Insertion

        /// Inserts an element's position into the hash table.
        ///
        /// - Parameters:
        ///   - position: The typed position in external storage.
        ///   - hashValue: The hash value of the element.
        ///   - equals: A closure that checks if the element at a given position
        ///     matches. Used to detect duplicates.
        /// - Returns: `true` if inserted, `false` if duplicate found.
        @inlinable
        @discardableResult
        public mutating func insert(
            position: Index_Primitives.Index<Element>,
            hashValue: Int,
            equals: (Index_Primitives.Index<Element>) -> Bool
        ) -> Bool {
            if shouldGrow {
                grow()
            }

            let hash = Self.normalize(hashValue)
            let hashCapacity = _storage.header.hashCapacity
            var bucket = Self.bucket(for: hash, capacity: hashCapacity)
            var firstDeleted: Int? = nil

            while true {
                let storedHash = _storage._readHash(at: bucket)

                if storedHash == Self.empty {
                    let insertBucket = firstDeleted ?? bucket
                    _storage._writeHash(at: insertBucket, value: hash)
                    _storage._writePosition(at: insertBucket, value: position.position)
                    _storage.header.count += 1
                    if firstDeleted == nil {
                        _storage.header.occupied += 1
                    }
                    return true
                }

                if storedHash == Self.deleted {
                    if firstDeleted == nil {
                        firstDeleted = bucket
                    }
                } else if storedHash == hash {
                    let rawPosition = _storage._readPosition(at: bucket)
                    let existingPosition = Index_Primitives.Index<Element>(__unchecked: (), position: rawPosition)
                    if equals(existingPosition) {
                        return false // Duplicate
                    }
                }

                bucket = Self.nextBucket(bucket, capacity: hashCapacity)
            }
        }

        /// Inserts without checking for duplicates.
        ///
        /// - Parameters:
        ///   - position: The typed position in external storage.
        ///   - hashValue: The hash value of the element.
        @inlinable
        public mutating func insert(
            __unchecked: Void,
            position: Index_Primitives.Index<Element>,
            hashValue: Int
        ) {
            if shouldGrow {
                grow()
            }

            let hash = Self.normalize(hashValue)
            let hashCapacity = _storage.header.hashCapacity
            var bucket = Self.bucket(for: hash, capacity: hashCapacity)

            while true {
                let storedHash = _storage._readHash(at: bucket)

                if storedHash == Self.empty || storedHash == Self.deleted {
                    _storage._writeHash(at: bucket, value: hash)
                    _storage._writePosition(at: bucket, value: position.position)
                    _storage.header.count += 1
                    if storedHash == Self.empty {
                        _storage.header.occupied += 1
                    }
                    return
                }

                bucket = Self.nextBucket(bucket, capacity: hashCapacity)
            }
        }

        // MARK: - Removal

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
            hashValue: Int,
            equals: (Index_Primitives.Index<Element>) -> Bool
        ) -> Index_Primitives.Index<Element>? {
            guard let bucket = bucket(forHash: hashValue, equals: equals) else {
                return nil
            }

            let rawPosition = _storage._readPosition(at: bucket)
            _storage._writeHash(at: bucket, value: Self.deleted)
            _storage.header.count -= 1
            return Index_Primitives.Index<Element>(__unchecked: (), position: rawPosition)
        }

        /// Removes the element at a specific bucket.
        ///
        /// - Parameter bucket: The bucket index to remove.
        @inlinable
        public mutating func remove(at bucket: Int) {
            precondition(_storage._readHash(at: bucket) != Self.empty && _storage._readHash(at: bucket) != Self.deleted)
            _storage._writeHash(at: bucket, value: Self.deleted)
            _storage.header.count -= 1
        }

        /// Removes all elements from the hash table.
        @inlinable
        public mutating func removeAll(keepingCapacity: Bool = false) {
            if keepingCapacity {
                let hashCapacity = _storage.header.hashCapacity
                for i in 0..<hashCapacity {
                    _storage._writeHash(at: i, value: Self.empty)
                }
                _storage.header.count = 0
                _storage.header.occupied = 0
            } else {
                // Create new storage with default capacity
                let hashCapacity = Self.capacity(for: 0)
                _storage = Storage.create(hashCapacity: hashCapacity)
            }
        }

        // MARK: - Position Updates

        /// Updates positions after an element is removed from external storage.
        ///
        /// When an element at `removedPosition` is removed from external storage,
        /// all positions greater than `removedPosition` must be decremented.
        ///
        /// - Parameter removedPosition: The typed position that was removed.
        @inlinable
        public mutating func decrementPositions(after removedPosition: Index_Primitives.Index<Element>) {
            let removedRaw = removedPosition.position
            let hashCapacity = _storage.header.hashCapacity
            for i in 0..<hashCapacity {
                let hash = _storage._readHash(at: i)
                if hash != Self.empty && hash != Self.deleted {
                    let pos = _storage._readPosition(at: i)
                    if pos > removedRaw {
                        _storage._writePosition(at: i, value: pos - 1)
                    }
                }
            }
        }

        // MARK: - Rehashing

        /// Whether the hash table should grow.
        @inlinable
        var shouldGrow: Bool {
            let hashCapacity = _storage.header.hashCapacity
            let occupied = _storage.header.occupied
            // Grow when occupied exceeds 70% of capacity
            return occupied * 10 >= hashCapacity * 7
        }

        /// Doubles the capacity and rehashes all elements.
        @inlinable
        mutating func grow() {
            let oldCapacity = _storage.header.hashCapacity
            let newCapacity = max(8, oldCapacity * 2)
            let newStorage = Storage.create(hashCapacity: newCapacity)

            for i in 0..<oldCapacity {
                let hash = _storage._readHash(at: i)
                if hash != Self.empty && hash != Self.deleted {
                    let position = _storage._readPosition(at: i)
                    var bucket = Self.bucket(for: hash, capacity: newCapacity)

                    while newStorage._readHash(at: bucket) != Self.empty {
                        bucket = Self.nextBucket(bucket, capacity: newCapacity)
                    }

                    newStorage._writeHash(at: bucket, value: hash)
                    newStorage._writePosition(at: bucket, value: position)
                }
            }

            newStorage.header.count = _storage.header.count
            newStorage.header.occupied = _storage.header.count
            _storage = newStorage
        }

        // MARK: - Hash Utilities

        /// Normalizes a hash value to avoid sentinel collisions.
        @inlinable
        static func normalize(_ hashValue: Int) -> Int {
            let hash = hashValue == 0 ? 1 : hashValue
            return hash == Int.min ? 1 : hash
        }

        /// Computes the initial bucket for a hash value.
        @inlinable
        static func bucket(for hash: Int, capacity: Int) -> Int {
            // capacity is power of two, so we can use bitmasking
            hash & (capacity - 1)
        }

        /// Computes the next bucket in the probe sequence.
        @inlinable
        static func nextBucket(_ bucket: Int, capacity: Int) -> Int {
            (bucket + 1) & (capacity - 1)
        }
    }
}

// MARK: - Conditional Copyable

/// `Hash.Table` is `Copyable` when its element type is `Copyable`.
///
/// This enables containers using `Hash.Table` (like `Set.Ordered`) to be
/// conditionally Copyable when their elements are Copyable.
extension Hash.Table: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Hash.Table: @unchecked Sendable where Element: ~Copyable {}
