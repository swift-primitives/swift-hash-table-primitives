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

public import Hash_Table_Primitives_Core

extension Hash.Table where Element: ~Copyable {
    /// Finds the position for an element with the given hash value.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to find.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the search element. Called for hash collisions.
    /// - Returns: The typed position in external storage if found, or `nil`.
    @inlinable
    public borrowing func position(
        forHash hashValue: Int,
        equals: (Index<Element>) -> Bool
    ) -> Index<Element>? {
        let hash = Self.normalize(hashValue)
        let capacity = Int(bitPattern: _storage.header.capacity)
        var bucketInt = hash & (capacity - 1)

        while true {
            let currentBucket = BucketIndex(__unchecked: (), Ordinal(UInt(bucketInt)))
            let storedHash = _storage.readHash(at: currentBucket)

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = _storage.readPosition(at: currentBucket)
                if equals(position) {
                    return position
                }
            }

            bucketInt = (bucketInt + 1) & (capacity - 1)
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
        forHash hashValue: Int,
        equals: (Index<Element>) -> Bool
    ) -> BucketIndex? {
        let hash = Self.normalize(hashValue)
        let capacity = Int(bitPattern: _storage.header.capacity)
        var bucketInt = hash & (capacity - 1)

        while true {
            let currentBucket = BucketIndex(__unchecked: (), Ordinal(UInt(bucketInt)))
            let storedHash = _storage.readHash(at: currentBucket)

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = _storage.readPosition(at: currentBucket)
                if equals(position) {
                    return currentBucket
                }
            }

            bucketInt = (bucketInt + 1) & (capacity - 1)
        }
    }
}
