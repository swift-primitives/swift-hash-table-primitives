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
    /// ## Move-Only
    ///
    /// `Hash.Table` is unconditionally `~Copyable` due to its deinit requirement
    /// for storage cleanup. This is consistent with first-class ~Copyable support.
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
        /// Hash values for each bucket.
        /// Uses sentinel values: 0 = empty, Int.min = deleted.
        @usableFromInline
        var _hashes: UnsafeMutablePointer<Int>

        /// Positions in external storage for each bucket (stored as raw Int).
        @usableFromInline
        var _positions: UnsafeMutablePointer<Int>

        /// The allocated capacity of the hash table.
        @usableFromInline
        var _capacity: Int

        /// Number of occupied buckets (excluding deleted).
        @usableFromInline
        var _count: Int

        /// Number of occupied + deleted buckets (for load factor).
        @usableFromInline
        var _occupied: Int

        // MARK: - Deinitialization

        deinit {
            if _capacity > 0 {
                unsafe _hashes.deallocate()
                unsafe _positions.deallocate()
            }
        }

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
            let capacity = Self.capacity(for: minimumCapacity)
            _capacity = capacity
            unsafe (_hashes = .allocate(capacity: capacity))
            unsafe (_positions = .allocate(capacity: capacity))
            unsafe _hashes.initialize(repeating: Self.empty, count: capacity)
            unsafe _positions.initialize(repeating: 0, count: capacity)
            _count = 0
            _occupied = 0
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
        public var count: Int { _count }

        /// Whether the hash table is empty.
        @inlinable
        public var isEmpty: Bool { _count == 0 }

        /// The current capacity of the hash table.
        @inlinable
        public var capacity: Int { _capacity }

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
            var bucket = Self.bucket(for: hash, capacity: _capacity)

            while true {
                let storedHash = unsafe _hashes[bucket]

                if storedHash == Self.empty {
                    return nil
                }

                if storedHash == hash {
                    let rawPosition = unsafe _positions[bucket]
                    let position = Index_Primitives.Index<Element>(__unchecked: (), position: rawPosition)
                    if equals(position) {
                        return position
                    }
                }

                bucket = Self.nextBucket(bucket, capacity: _capacity)
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
            var bucket = Self.bucket(for: hash, capacity: _capacity)

            while true {
                let storedHash = unsafe _hashes[bucket]

                if storedHash == Self.empty {
                    return nil
                }

                if storedHash == hash {
                    let rawPosition = unsafe _positions[bucket]
                    let position = Index_Primitives.Index<Element>(__unchecked: (), position: rawPosition)
                    if equals(position) {
                        return bucket
                    }
                }

                bucket = Self.nextBucket(bucket, capacity: _capacity)
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
            var bucket = Self.bucket(for: hash, capacity: _capacity)
            var firstDeleted: Int? = nil

            while true {
                let storedHash = unsafe _hashes[bucket]

                if storedHash == Self.empty {
                    let insertBucket = firstDeleted ?? bucket
                    unsafe (_hashes[insertBucket] = hash)
                    unsafe (_positions[insertBucket] = position.position.rawValue)
                    _count += 1
                    if firstDeleted == nil {
                        _occupied += 1
                    }
                    return true
                }

                if storedHash == Self.deleted {
                    if firstDeleted == nil {
                        firstDeleted = bucket
                    }
                } else if storedHash == hash {
                    let rawPosition = unsafe _positions[bucket]
                    let existingPosition = Index_Primitives.Index<Element>(__unchecked: (), position: rawPosition)
                    if equals(existingPosition) {
                        return false // Duplicate
                    }
                }

                bucket = Self.nextBucket(bucket, capacity: _capacity)
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
            var bucket = Self.bucket(for: hash, capacity: _capacity)

            while true {
                let storedHash = unsafe _hashes[bucket]

                if storedHash == Self.empty || storedHash == Self.deleted {
                    unsafe (_hashes[bucket] = hash)
                    unsafe (_positions[bucket] = position.position.rawValue)
                    _count += 1
                    if storedHash == Self.empty {
                        _occupied += 1
                    }
                    return
                }

                bucket = Self.nextBucket(bucket, capacity: _capacity)
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

            let rawPosition = unsafe _positions[bucket]
            unsafe (_hashes[bucket] = Self.deleted)
            _count -= 1
            return Index_Primitives.Index<Element>(__unchecked: (), position: rawPosition)
        }

        /// Removes the element at a specific bucket.
        ///
        /// - Parameter bucket: The bucket index to remove.
        @inlinable
        public mutating func remove(at bucket: Int) {
            precondition(unsafe _hashes[bucket] != Self.empty && _hashes[bucket] != Self.deleted)
            unsafe (_hashes[bucket] = Self.deleted)
            _count -= 1
        }

        /// Removes all elements from the hash table.
        @inlinable
        public mutating func removeAll(keepingCapacity: Bool = false) {
            if keepingCapacity {
                for i in 0..<_capacity {
                    unsafe (_hashes[i] = Self.empty)
                }
                _count = 0
                _occupied = 0
            } else {
                // Deallocate old storage
                if _capacity > 0 {
                    unsafe _hashes.deallocate()
                    unsafe _positions.deallocate()
                }
                // Reinitialize with default capacity
                let capacity = Self.capacity(for: 0)
                _capacity = capacity
                unsafe (_hashes = .allocate(capacity: capacity))
                unsafe (_positions = .allocate(capacity: capacity))
                unsafe _hashes.initialize(repeating: Self.empty, count: capacity)
                unsafe _positions.initialize(repeating: 0, count: capacity)
                _count = 0
                _occupied = 0
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
            let removedRaw = removedPosition.position.rawValue
            for i in 0..<_capacity {
                let hash = unsafe _hashes[i]
                if hash != Self.empty && hash != Self.deleted {
                    if unsafe _positions[i] > removedRaw {
                        unsafe (_positions[i] -= 1)
                    }
                }
            }
        }

        // MARK: - Rehashing

        /// Whether the hash table should grow.
        @inlinable
        var shouldGrow: Bool {
            // Grow when occupied exceeds 70% of capacity
            _occupied * 10 >= _capacity * 7
        }

        /// Doubles the capacity and rehashes all elements.
        @inlinable
        mutating func grow() {
            let newCapacity = max(8, _capacity * 2)
            let newHashes = UnsafeMutablePointer<Int>.allocate(capacity: newCapacity)
            let newPositions = UnsafeMutablePointer<Int>.allocate(capacity: newCapacity)
            unsafe newHashes.initialize(repeating: Self.empty, count: newCapacity)
            unsafe newPositions.initialize(repeating: 0, count: newCapacity)

            for i in 0..<_capacity {
                let hash = unsafe _hashes[i]
                if hash != Self.empty && hash != Self.deleted {
                    let position = unsafe _positions[i]
                    var bucket = Self.bucket(for: hash, capacity: newCapacity)

                    while unsafe newHashes[bucket] != Self.empty {
                        bucket = Self.nextBucket(bucket, capacity: newCapacity)
                    }

                    unsafe (newHashes[bucket] = hash)
                    unsafe (newPositions[bucket] = position)
                }
            }

            // Deallocate old storage
            if _capacity > 0 {
                unsafe _hashes.deallocate()
                unsafe _positions.deallocate()
            }

            unsafe (_hashes = newHashes)
            unsafe (_positions = newPositions)
            _capacity = newCapacity
            _occupied = _count
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

// MARK: - Sendable

extension Hash.Table: @unchecked Sendable where Element: ~Copyable {}
