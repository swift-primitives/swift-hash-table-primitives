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
        forHash hashValue: Hash.Value,
        equals: (Index<Element>) -> Bool
    ) -> Index<Element>? {
        let hash = Self.normalize(hashValue)
        let capacity = bucketCapacity
        var currentBucket = BucketIndex(
            __unchecked: (),
            Ordinal(UInt(bitPattern: hash)) % capacity.rawValue
        )
        var probes: Index<Bucket>.Count = .zero

        while probes < capacity {
            let storedHash = self[hash: currentBucket]

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = self[position: currentBucket]
                if equals(position) {
                    return position
                }
            }

            currentBucket = BucketIndex.Modular.successor(of: currentBucket, capacity: capacity)
            probes += .one
        }

        return nil
    }

    /// Finds the position for an element with the given hash value,
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
    /// - Returns: The typed position in external storage if found, or `nil`.
    @inlinable
    public borrowing func position<Context: ~Copyable>(
        forHash hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Index<Element>, borrowing Context) -> Bool
    ) -> Index<Element>? {
        let hash = Self.normalize(hashValue)
        let capacity = bucketCapacity
        var currentBucket = BucketIndex(
            __unchecked: (),
            Ordinal(UInt(bitPattern: hash)) % capacity.rawValue
        )
        var probes: Index<Bucket>.Count = .zero

        while probes < capacity {
            let storedHash = self[hash: currentBucket]

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = self[position: currentBucket]
                if equals(position, context) {
                    return position
                }
            }

            currentBucket = BucketIndex.Modular.successor(of: currentBucket, capacity: capacity)
            probes += .one
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
        equals: (Index<Element>) -> Bool
    ) -> BucketIndex? {
        let hash = Self.normalize(hashValue)
        let capacity = bucketCapacity
        var currentBucket = BucketIndex(
            __unchecked: (),
            Ordinal(UInt(bitPattern: hash)) % capacity.rawValue
        )
        var probes: Index<Bucket>.Count = .zero

        while probes < capacity {
            let storedHash = self[hash: currentBucket]

            if storedHash == Self.empty {
                return nil
            }

            if storedHash == hash {
                let position = self[position: currentBucket]
                if equals(position) {
                    return currentBucket
                }
            }

            currentBucket = BucketIndex.Modular.successor(of: currentBucket, capacity: capacity)
            probes += .one
        }

        return nil
    }
}
