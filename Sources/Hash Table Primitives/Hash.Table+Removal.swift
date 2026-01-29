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
        equals: (Index<Element>) -> Bool
    ) -> Index<Element>? {
        guard let bucketIdx = bucketIndex(forHash: hashValue, equals: equals) else {
            return nil
        }

        let position = _storage.readPosition(at: bucketIdx)
        _storage.writeHash(at: bucketIdx, value: Self.deleted)
        _storage.header.count = Index<Element>.Count(
            Cardinal(_storage.header.count.rawValue.rawValue - 1)
        )
        return position
    }

    /// Removes the element at a specific bucket.
    ///
    /// - Parameter bucket: The bucket index to remove.
    @inlinable
    public mutating func remove(at bucketIdx: BucketIndex) {
        precondition(
            _storage.readHash(at: bucketIdx) != Self.empty &&
            _storage.readHash(at: bucketIdx) != Self.deleted
        )
        _storage.writeHash(at: bucketIdx, value: Self.deleted)
        _storage.header.count = Index<Element>.Count(
            Cardinal(_storage.header.count.rawValue.rawValue - 1)
        )
    }

    /// Removes all elements from the hash table.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        if keepingCapacity {
            let cap = Int(_storage.header.capacity.rawValue.rawValue)
            for i in 0..<cap {
                let bucketIdx = BucketIndex(__unchecked: (), Ordinal(UInt(i)))
                _storage.writeHash(at: bucketIdx, value: Self.empty)
            }
            _storage.header.count = .zero
            _storage.header.occupied = .zero
        } else {
            // Create new storage with default capacity
            let hashCapacity = Self.bucketCapacity(for: .zero)
            _storage = Storage.create(capacity: hashCapacity)
        }
    }
}
