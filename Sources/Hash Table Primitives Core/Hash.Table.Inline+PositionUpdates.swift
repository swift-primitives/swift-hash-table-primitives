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

extension Hash.Table.Inline where Element: ~Copyable {
    /// Updates positions after an element is removed from external storage.
    ///
    /// When an element at `removedPosition` is removed from external storage
    /// (e.g., an array), and remaining elements shift left to fill the gap,
    /// all positions in the hash table greater than `removedPosition` must
    /// be decremented to maintain correct references.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Remove element at position 2 from array
    /// let value = array.remove(at: 2)
    /// // Array elements at positions 3, 4, 5... shift to 2, 3, 4...
    /// // Update hash table to reflect the shift
    /// hashTable.decrementPositions(after: Index(2))
    /// ```
    ///
    /// - Parameter removedPosition: The typed position that was removed.
    ///
    /// - Complexity: O(n) where n is bucket capacity.
    @inlinable
    public mutating func decrementPositions(after removedPosition: Index<Element>) {
        let removedRaw = Int(bitPattern: removedPosition.position.rawValue)

        for i in 0..<bucketCapacity {
            let hash = _hashes[i]
            if hash != Self.empty && hash != Self.deleted {
                let posRaw = _positions[i]
                if posRaw > removedRaw {
                    _positions[i] = posRaw - 1
                }
            }
        }
    }

    /// Updates the position for an element with the given hash value.
    ///
    /// Use this when an element's position in external storage changes
    /// without being removed (e.g., during a swap operation).
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to update.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the element to update.
    ///   - newPosition: The new position for the element.
    /// - Returns: `true` if the position was updated, `false` if element not found.
    @inlinable
    @discardableResult
    public mutating func updatePosition(
        forHash hashValue: Int,
        equals: (Index<Element>) -> Bool,
        newPosition: Index<Element>
    ) -> Bool {
        guard let bucket = bucketIndex(forHash: hashValue, equals: equals) else {
            return false
        }
        _positions[bucket] = Int(bitPattern: newPosition.position.rawValue)
        return true
    }

    /// Updates the position at a specific bucket index.
    ///
    /// - Parameters:
    ///   - bucket: The bucket index to update.
    ///   - newPosition: The new position value.
    ///
    /// - Precondition: The bucket must contain a valid element.
    @inlinable
    public mutating func updatePosition(atBucket bucket: Int, newPosition: Index<Element>) {
        precondition(
            _hashes[bucket] != Self.empty && _hashes[bucket] != Self.deleted,
            "Cannot update position of empty or deleted bucket"
        )
        _positions[bucket] = Int(bitPattern: newPosition.position.rawValue)
    }
}
