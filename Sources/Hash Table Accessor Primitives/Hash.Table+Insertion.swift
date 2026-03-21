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
        hashValue: Hash.Value,
        equals: (Index<Element>) -> Bool
    ) -> Bool {
        if shouldGrow {
            grow()
        }

        let hash = Self.normalize(hashValue)
        var currentBucket = bucket.for(hash: hash)
        var firstDeleted: Bucket.Index? = nil
        var probes: Index<Bucket>.Count = .zero
        let cap = bucketCapacity

        while probes < cap {
            let storedHash = self[hash: currentBucket]

            if storedHash == Self.empty {
                let insertBucket = firstDeleted ?? currentBucket
                self[hash: insertBucket] = hash
                self[position: insertBucket] = position
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
                let existingPosition = self[position: currentBucket]
                if equals(existingPosition) {
                    return false // Duplicate
                }
            }

            currentBucket = bucket.next(currentBucket)
            probes += .one
        }

        // All buckets probed — insert at first deleted if available
        if let insertBucket = firstDeleted {
            self[hash: insertBucket] = hash
            self[position: insertBucket] = position
            _count = _count + .one
            return true
        }

        return false
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
        hashValue: Hash.Value
    ) {
        if shouldGrow {
            grow()
        }

        let hash = Self.normalize(hashValue)
        var currentBucket = bucket.for(hash: hash)
        var probes: Index<Bucket>.Count = .zero
        let cap = bucketCapacity

        while probes < cap {
            let storedHash = self[hash: currentBucket]

            if storedHash == Self.empty || storedHash == Self.deleted {
                self[hash: currentBucket] = hash
                self[position: currentBucket] = position
                _count = _count + .one
                if storedHash == Self.empty {
                    _occupied = _occupied + .one
                }
                return
            }

            currentBucket = bucket.next(currentBucket)
            probes += .one
        }
    }

    /// Doubles the capacity and rehashes all elements.
    @inlinable
    mutating func grow() {
        let oldCapacity = bucketCapacity
        let newCapacity = Index<Bucket>.Count.max(
            Index<Bucket>.Count(Cardinal(8 as UInt)),
            oldCapacity * 2
        )
        var newBuffer = Buffer<Int>.Slots<Int>(
            capacity: newCapacity.retag(Int.self),
            metadataInitial: Self.empty
        )
        newBuffer.fill(payload: 0)

        var bucket: Bucket.Index = .zero
        var remaining = _count
        while bucket < oldCapacity, remaining != .zero {
            let hash = self[hash: bucket]
            if hash != Self.empty && hash != Self.deleted {
                let position = self[position: bucket]
                var targetBucket = Self.bucket(for: hash, capacity: newCapacity)

                var probes: Index<Bucket>.Count = .zero
                while newBuffer[metadata: targetBucket.retag(Int.self)] != Self.empty && probes < newCapacity {
                    targetBucket = Bucket.Index.Modular.successor(of: targetBucket, capacity: newCapacity)
                    probes += .one
                }

                newBuffer[metadata: targetBucket.retag(Int.self)] = hash
                newBuffer[payload: targetBucket.retag(Int.self)] = Int(bitPattern: position)
                remaining = remaining.subtract.saturating(.one)
            }
            bucket += .one
        }

        // After rehashing, occupied = count (no deleted buckets)
        _occupied = _count.retag(Bucket.self)
        _buffer = newBuffer
    }
}
