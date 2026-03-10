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
    /// Finds the bounded position for an element with the given hash value.
    ///
    /// Uses linear probing to search for the element. The `equals` closure
    /// is called on hash collisions to verify the correct element.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to find.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the search element. Called for hash collisions.
    /// - Returns: The bounded position in external storage if found, or `nil`.
    ///
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    public borrowing func position(
        forHash hashValue: Hash.Value,
        equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool
    ) -> Index<Element>.Bounded<bucketCapacity>? {
        let hash = Self.normalize(hashValue)
        var currentBucket = bucket(for: hash)
        var probes = 0

        while probes < bucketCapacity {
            let storedHash = readHash(at: currentBucket)

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = readPosition(at: currentBucket)
                if equals(position) {
                    return position
                }
            }

            currentBucket = bucket(after: currentBucket)
            probes += 1
        }

        return nil
    }

    /// Finds the bounded position for an element with the given hash value,
    /// passing a context value through to the equality closure.
    ///
    /// This overload avoids capturing the search element in the closure,
    /// which is required when the element is `borrowing` and `~Copyable`.
    /// The context is passed as a parameter to each `equals` invocation.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to find.
    ///   - context: A value passed through to `equals` on each probe.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the context. Called for hash collisions.
    /// - Returns: The bounded position in external storage if found, or `nil`.
    ///
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    public borrowing func position<Context: ~Copyable>(
        forHash hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Index<Element>.Bounded<bucketCapacity>, borrowing Context) -> Bool
    ) -> Index<Element>.Bounded<bucketCapacity>? {
        let hash = Self.normalize(hashValue)
        var currentBucket = bucket(for: hash)
        var probes = 0

        while probes < bucketCapacity {
            let storedHash = readHash(at: currentBucket)

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = readPosition(at: currentBucket)
                if equals(position, context) {
                    return position
                }
            }

            currentBucket = bucket(after: currentBucket)
            probes += 1
        }

        return nil
    }

    /// Finds the bucket index for an element with the given hash value.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to find.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the search element.
    /// - Returns: The bucket index if found, or `nil`.
    @inlinable
    public borrowing func bucketIndex(
        forHash hashValue: Hash.Value,
        equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool
    ) -> Bucket.Index? {
        let hash = Self.normalize(hashValue)
        var currentBucket = bucket(for: hash)
        var probes = 0

        while probes < bucketCapacity {
            let storedHash = readHash(at: currentBucket)

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = readPosition(at: currentBucket)
                if equals(position) {
                    return currentBucket
                }
            }

            currentBucket = bucket(after: currentBucket)
            probes += 1
        }

        return nil
    }

    /// Checks whether an element with the given hash value exists.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to check.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the search element.
    /// - Returns: `true` if the element exists, `false` otherwise.
    @inlinable
    public borrowing func contains(
        hashValue: Hash.Value,
        equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool
    ) -> Bool {
        position(forHash: hashValue, equals: equals) != nil
    }
}
