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
    /// Finds the position for an element with the given hash value.
    ///
    /// Uses linear probing to search for the element. The `equals` closure
    /// is called on hash collisions to verify the correct element.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to find.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the search element. Called for hash collisions.
    /// - Returns: The typed position in external storage if found, or `nil`.
    ///
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    public borrowing func position(
        forHash hashValue: Hash.Value,
        equals: (Index<Element>) -> Bool
    ) -> Index<Element>? {
        let hash = Self.normalize(hashValue)
        var bucket = bucketFor(hash: hash)

        while true {
            let bi = Int(bitPattern: bucket.position.rawValue)
            let storedHash = _hashes[bi]

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: _positions[bi])))
                if equals(position) {
                    return position
                }
            }

            // Skip deleted buckets but continue probing
            bucket = nextBucket(bucket)
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
    public borrowing func bucketIndex(
        forHash hashValue: Hash.Value,
        equals: (Index<Element>) -> Bool
    ) -> BucketIndex? {
        let hash = Self.normalize(hashValue)
        var bucket = bucketFor(hash: hash)

        while true {
            let bi = Int(bitPattern: bucket.position.rawValue)
            let storedHash = _hashes[bi]

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: _positions[bi])))
                if equals(position) {
                    return bucket
                }
            }

            bucket = nextBucket(bucket)
        }
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
        equals: (Index<Element>) -> Bool
    ) -> Bool {
        position(forHash: hashValue, equals: equals) != nil
    }
}
