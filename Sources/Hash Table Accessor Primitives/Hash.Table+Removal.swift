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
