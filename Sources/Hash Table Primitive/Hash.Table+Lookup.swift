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

import Affine_Primitives_Standard_Library_Integration
public import Buffer_Slots_Primitive
public import Hash_Primitives
public import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration

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
        let capacityCount = bucketCapacity
        // Power-of-two capacity (bucketCapacity(for:) rounds up; growth
        // doubles), so `& mask` is the cyclic successor.
        let capacity = Int(bitPattern: capacityCount)
        let mask = capacity &- 1
        var bucket = Int(bitPattern: Self.bucket(for: hash, seed: _seed, capacity: capacityCount))
        var probes = 0
        // B-8 span-first: the hash-plane base is hoisted ONCE for the whole
        // walk (under `Shared`, per-access subscripts re-derive it through the
        // box each step — the measured read tax).
        return unsafe _buffer.withMetadataPointer { (hashes: UnsafePointer<Int>) -> Index<Element>? in
            while probes < capacity {
                // WHY: `bucket` stays in [0, capacity) under the mask; the
                // metadata span covers exactly [0, capacity).
                let storedHash = unsafe hashes[bucket]

                if storedHash == Self.empty {
                    return nil
                }

                if storedHash == hash {
                    let position = self[position: Bucket.Index(_unchecked: Ordinal(UInt(bitPattern: bucket)))]
                    if equals(position) {
                        return position
                    }
                }

                bucket = (bucket &+ 1) & mask
                probes &+= 1
            }

            return nil
        }
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
        let capacityCount = bucketCapacity
        // Power-of-two capacity — `& mask` is the cyclic successor (see the
        // closure-form overload).
        let capacity = Int(bitPattern: capacityCount)
        let mask = capacity &- 1
        var bucket = Int(bitPattern: Self.bucket(for: hash, seed: _seed, capacity: capacityCount))
        var probes = 0
        return unsafe _buffer.withMetadataPointer { (hashes: UnsafePointer<Int>) -> Index<Element>? in
            while probes < capacity {
                // WHY: `bucket` stays in [0, capacity) under the mask.
                let storedHash = unsafe hashes[bucket]

                if storedHash == Self.empty {
                    return nil
                }

                if storedHash == hash {
                    let position = self[position: Bucket.Index(_unchecked: Ordinal(UInt(bitPattern: bucket)))]
                    if equals(position, context) {
                        return position
                    }
                }

                bucket = (bucket &+ 1) & mask
                probes &+= 1
            }

            return nil
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
    public borrowing func index(
        forHash hashValue: Hash.Value,
        equals: (Index<Element>) -> Bool
    ) -> Bucket.Index? {
        let hash = Self.normalize(hashValue)
        let capacityCount = bucketCapacity
        // Power-of-two capacity — `& mask` is the cyclic successor.
        let capacity = Int(bitPattern: capacityCount)
        let mask = capacity &- 1
        var bucket = Int(bitPattern: Self.bucket(for: hash, seed: _seed, capacity: capacityCount))
        var probes = 0
        return unsafe _buffer.withMetadataPointer { (hashes: UnsafePointer<Int>) -> Bucket.Index? in
            while probes < capacity {
                // WHY: `bucket` stays in [0, capacity) under the mask.
                let storedHash = unsafe hashes[bucket]

                if storedHash == Self.empty {
                    return nil
                }

                if storedHash == hash {
                    let found = Bucket.Index(_unchecked: Ordinal(UInt(bitPattern: bucket)))
                    let position = self[position: found]
                    if equals(position) {
                        return found
                    }
                }

                bucket = (bucket &+ 1) & mask
                probes &+= 1
            }

            return nil
        }
    }

    /// Finds the bucket index for an element with the given hash value,
    /// passing a context value through to the equality closure.
    ///
    /// This overload avoids capturing the search element in the closure,
    /// which is required when the element is `borrowing` and `~Copyable`.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to find.
    ///   - context: A value passed through to `equals` on each probe.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the context.
    /// - Returns: The bucket index if found, or `nil`.
    @inlinable
    public borrowing func index<Context: ~Copyable>(
        forHash hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Index<Element>, borrowing Context) -> Bool
    ) -> Bucket.Index? {
        let hash = Self.normalize(hashValue)
        let capacityCount = bucketCapacity
        // Power-of-two capacity — `& mask` is the cyclic successor.
        let capacity = Int(bitPattern: capacityCount)
        let mask = capacity &- 1
        var bucket = Int(bitPattern: Self.bucket(for: hash, seed: _seed, capacity: capacityCount))
        var probes = 0
        return unsafe _buffer.withMetadataPointer { (hashes: UnsafePointer<Int>) -> Bucket.Index? in
            while probes < capacity {
                // WHY: `bucket` stays in [0, capacity) under the mask.
                let storedHash = unsafe hashes[bucket]

                if storedHash == Self.empty {
                    return nil
                }

                if storedHash == hash {
                    let found = Bucket.Index(_unchecked: Ordinal(UInt(bitPattern: bucket)))
                    let position = self[position: found]
                    if equals(position, context) {
                        return found
                    }
                }

                bucket = (bucket &+ 1) & mask
                probes &+= 1
            }

            return nil
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

    /// Checks whether an element with the given hash value exists,
    /// passing a context value through to the equality closure.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to check.
    ///   - context: A value passed through to `equals` on each probe.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the context.
    /// - Returns: `true` if the element exists, `false` otherwise.
    @inlinable
    public borrowing func contains<Context: ~Copyable>(
        forHash hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Index<Element>, borrowing Context) -> Bool
    ) -> Bool {
        position(forHash: hashValue, context: context, equals: equals) != nil
    }
}
