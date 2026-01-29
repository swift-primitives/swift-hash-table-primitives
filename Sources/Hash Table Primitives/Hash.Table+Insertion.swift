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
public import Cardinal_Primitives
public import Ordinal_Primitives

extension Hash.Table where Element: ~Copyable {
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
        position: Index<Element>,
        hashValue: Int,
        equals: (Index<Element>) -> Bool
    ) -> Bool {
        if shouldGrow {
            grow()
        }

        let hash = Self.normalize(hashValue)
        var currentBucket = bucket.for(hash: hash)
        var firstDeleted: BucketIndex? = nil

        while true {
            let storedHash = _storage.readHash(at: currentBucket)

            if storedHash == Self.empty {
                let insertBucket = firstDeleted ?? currentBucket
                _storage.writeHash(at: insertBucket, value: hash)
                _storage.writePosition(at: insertBucket, value: position)
                _storage.header.count = Index<Element>.Count(
                    Cardinal(_storage.header.count.rawValue.rawValue + 1)
                )
                if firstDeleted == nil {
                    _storage.header.occupied = Index<Bucket>.Count(
                        Cardinal(_storage.header.occupied.rawValue.rawValue + 1)
                    )
                }
                return true
            }

            if storedHash == Self.deleted {
                if firstDeleted == nil {
                    firstDeleted = currentBucket
                }
            } else if storedHash == hash {
                let existingPosition = _storage.readPosition(at: currentBucket)
                if equals(existingPosition) {
                    return false // Duplicate
                }
            }

            currentBucket = bucket.next(currentBucket)
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
        position: Index<Element>,
        hashValue: Int
    ) {
        if shouldGrow {
            grow()
        }

        let hash = Self.normalize(hashValue)
        var currentBucket = bucket.for(hash: hash)

        while true {
            let storedHash = _storage.readHash(at: currentBucket)

            if storedHash == Self.empty || storedHash == Self.deleted {
                _storage.writeHash(at: currentBucket, value: hash)
                _storage.writePosition(at: currentBucket, value: position)
                _storage.header.count = Index<Element>.Count(
                    Cardinal(_storage.header.count.rawValue.rawValue + 1)
                )
                if storedHash == Self.empty {
                    _storage.header.occupied = Index<Bucket>.Count(
                        Cardinal(_storage.header.occupied.rawValue.rawValue + 1)
                    )
                }
                return
            }

            currentBucket = bucket.next(currentBucket)
        }
    }

    /// Doubles the capacity and rehashes all elements.
    @inlinable
    mutating func grow() {
        let oldCapacity = _storage.header.capacity
        let oldCapInt = Int(oldCapacity.rawValue.rawValue)
        let newCapacity = Index<Bucket>.Count(Cardinal(UInt(max(8, oldCapInt * 2))))
        let newStorage = Storage.create(capacity: newCapacity)
        let newCapInt = Int(newCapacity.rawValue.rawValue)

        for i in 0..<oldCapInt {
            let bucketIdx = BucketIndex(__unchecked: (), Ordinal(UInt(i)))
            let hash = _storage.readHash(at: bucketIdx)
            if hash != Self.empty && hash != Self.deleted {
                let position = _storage.readPosition(at: bucketIdx)
                var targetBucket = BucketIndex(__unchecked: (), Ordinal(UInt(hash & (newCapInt - 1))))

                while newStorage.readHash(at: targetBucket) != Self.empty {
                    let next = (Int(bitPattern: targetBucket.position.rawValue) + 1) & (newCapInt - 1)
                    targetBucket = BucketIndex(__unchecked: (), Ordinal(UInt(next)))
                }

                newStorage.writeHash(at: targetBucket, value: hash)
                newStorage.writePosition(at: targetBucket, value: position)
            }
        }

        newStorage.header.count = _storage.header.count
        // After rehashing, occupied = count (no deleted buckets)
        newStorage.header.occupied = Index<Bucket>.Count(_storage.header.count.rawValue)
        _storage = newStorage
    }
}
