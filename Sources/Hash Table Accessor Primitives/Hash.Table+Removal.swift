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
internal import Property_Primitives

extension Hash.Table.Remove where Element: ~Copyable {
    public typealias View = Property<Hash.Table<Element>.Remove, Hash.Table<Element>>.View.Typed<Element>
}

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
        hashValue: Hash.Value,
        equals: (Index<Element>) -> Bool
    ) -> Index<Element>? {
        guard let bucketIdx = bucketIndex(forHash: hashValue, equals: equals) else {
            return nil
        }

        let position = self[position: bucketIdx]
        self[hash: bucketIdx] = Self.deleted
        _count = _count.subtract.saturating(.one)
        return position
    }

    /// Removes an element from the hash table, passing a context value
    /// through to the equality closure instead of capturing it.
    ///
    /// This overload avoids capturing the search element in the closure,
    /// which is required when the element is `borrowing` and `~Copyable`.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to remove.
    ///   - context: A value passed through to `equals` on each probe.
    ///   - equals: A closure that checks if the element at a given position
    ///     matches the context.
    /// - Returns: The typed position that was removed, or `nil` if not found.
    @inlinable
    @discardableResult
    public mutating func remove<Context: ~Copyable>(
        hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Index<Element>, borrowing Context) -> Bool
    ) -> Index<Element>? {
        let hash = Self.normalize(hashValue)
        let capacity = bucketCapacity
        var currentBucket = Bucket.Index(
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
                    self[hash: currentBucket] = Self.deleted
                    _count = _count.subtract.saturating(.one)
                    return position
                }
            }

            currentBucket = Bucket.Index.Modular.successor(of: currentBucket, capacity: capacity)
            probes += .one
        }

        return nil
    }

    /// Removes the element at a specific bucket.
    ///
    /// - Parameter bucket: The bucket index to remove.
    @inlinable
    public mutating func remove(at bucketIdx: Bucket.Index) {
        precondition(
            self[hash: bucketIdx] != Self.empty &&
            self[hash: bucketIdx] != Self.deleted
        )
        self[hash: bucketIdx] = Self.deleted
        _count = _count.subtract.saturating(.one)
    }

    /// Access remove operations.
    @inlinable
    public var remove: Remove.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Remove.View = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property.View.Typed
where Tag == Hash.Table<Element>.Remove, Base == Hash.Table<Element>, Element: ~Copyable {
    /// Removes all elements.
    @inlinable
    public mutating func all(keepingCapacity: Bool = false) {
        if keepingCapacity {
            unsafe base.pointee._buffer.fill(metadata: Hash.Table<Element>.empty)
            unsafe base.pointee._buffer.fill(payload: 0)
            unsafe base.pointee._count = .zero
            unsafe base.pointee._occupied = .zero
        } else {
            let hashCapacity = Hash.Table<Element>.bucketCapacity(for: .zero)
            let buffer = Buffer<Int>.Slots<Int>(
                capacity: hashCapacity.retag(Int.self),
                metadataInitial: Hash.Table<Element>.empty
            )
            buffer.fill(payload: 0)
            unsafe base.pointee._buffer = buffer
            unsafe base.pointee._count = .zero
            unsafe base.pointee._occupied = .zero
        }
    }
}
