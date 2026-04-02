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

extension Hash.Table.Static where Element: ~Copyable {
    /// Inserts an element's bounded position into the hash table.
    ///
    /// Uses linear probing to find an empty or deleted bucket. Reuses
    /// deleted buckets (tombstones) when possible.
    ///
    /// - Parameters:
    ///   - position: The bounded position in external storage.
    ///   - hashValue: The hash value of the element.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches. Used to detect duplicates.
    /// - Returns: `true` if inserted, `false` if duplicate found or table is full.
    ///
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    @discardableResult
    public mutating func insert(
        position: Index<Element>.Bounded<bucketCapacity>,
        hashValue: Hash.Value,
        equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool
    ) -> Bool {
        // Check if table is full
        if isFull {
            return false
        }

        let hash = Self.normalize(hashValue)
        var currentBucket = bucket(for: hash)
        var firstDeleted: Bucket.Index? = nil
        var probes = 0

        while probes < bucketCapacity {
            let storedHash = readHash(at: currentBucket)

            if storedHash == Self.empty {
                // Found empty bucket - insert here or at first deleted
                let insertBucket = firstDeleted ?? currentBucket
                writeHash(at: insertBucket, value: hash)
                writePosition(at: insertBucket, value: position)
                _count = _count + .one
                if firstDeleted == nil {
                    _occupied = _occupied + .one
                }
                return true
            }

            if storedHash == Self.deleted {
                // Remember first deleted bucket for potential reuse
                if firstDeleted == nil {
                    firstDeleted = currentBucket
                }
            } else if storedHash == hash {
                // Hash match - check for duplicate
                let existingPosition = readPosition(at: currentBucket)
                if equals(existingPosition) {
                    return false // Duplicate found
                }
            }

            currentBucket = bucket(after: currentBucket)
            probes += 1
        }

        // All buckets probed — insert at first deleted if available
        if let insertBucket = firstDeleted {
            writeHash(at: insertBucket, value: hash)
            writePosition(at: insertBucket, value: position)
            _count = _count + .one
            return true
        }

        return false
    }

    /// Inserts an element's bounded position into the hash table,
    /// passing a context value through to the equality closure.
    ///
    /// This overload avoids capturing the search element in the closure,
    /// which is required when the element is `borrowing` and `~Copyable`.
    ///
    /// - Parameters:
    ///   - position: The bounded position in external storage.
    ///   - hashValue: The hash value of the element.
    ///   - context: A value passed through to `equals` on each probe.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the context. Used to detect duplicates.
    /// - Returns: `true` if inserted, `false` if duplicate found or table is full.
    ///
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    @discardableResult
    public mutating func insert<Context: ~Copyable>(
        position: Index<Element>.Bounded<bucketCapacity>,
        hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Index<Element>.Bounded<bucketCapacity>, borrowing Context) -> Bool
    ) -> Bool {
        if isFull {
            return false
        }

        let hash = Self.normalize(hashValue)
        var currentBucket = bucket(for: hash)
        var firstDeleted: Bucket.Index? = nil
        var probes = 0

        while probes < bucketCapacity {
            let storedHash = readHash(at: currentBucket)

            if storedHash == Self.empty {
                let insertBucket = firstDeleted ?? currentBucket
                writeHash(at: insertBucket, value: hash)
                writePosition(at: insertBucket, value: position)
                _count = _count + .one
                if firstDeleted == nil {
                    _occupied = _occupied + .one
                }
                return true
            }

            if storedHash == Self.deleted {
                if firstDeleted == nil {
                    firstDeleted = currentBucket
                }
            } else if storedHash == hash {
                let existingPosition = readPosition(at: currentBucket)
                if equals(existingPosition, context) {
                    return false
                }
            }

            currentBucket = bucket(after: currentBucket)
            probes += 1
        }

        if let insertBucket = firstDeleted {
            writeHash(at: insertBucket, value: hash)
            writePosition(at: insertBucket, value: position)
            _count = _count + .one
            return true
        }

        return false
    }

    /// Inserts without checking for duplicates.
    ///
    /// Use when you know the element is not already in the table.
    ///
    /// - Parameters:
    ///   - position: The bounded position in external storage.
    ///   - hashValue: The hash value of the element.
    /// - Returns: `true` if inserted, `false` if table is full.
    ///
    /// - Precondition: The element must not already exist in the table.
    @inlinable
    @discardableResult
    public mutating func insert(
        __unchecked: Void,
        position: Index<Element>.Bounded<bucketCapacity>,
        hashValue: Hash.Value
    ) -> Bool {
        if isFull {
            return false
        }

        let hash = Self.normalize(hashValue)
        var currentBucket = bucket(for: hash)
        var probes = 0

        while probes < bucketCapacity {
            let storedHash = readHash(at: currentBucket)

            if storedHash == Self.empty || storedHash == Self.deleted {
                writeHash(at: currentBucket, value: hash)
                writePosition(at: currentBucket, value: position)
                _count = _count + .one
                if storedHash == Self.empty {
                    _occupied = _occupied + .one
                }
                return true
            }

            currentBucket = bucket(after: currentBucket)
            probes += 1
        }

        return false
    }
}
