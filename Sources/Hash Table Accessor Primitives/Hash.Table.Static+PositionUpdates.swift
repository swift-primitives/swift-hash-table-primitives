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
public import Property_Primitives

extension Hash.Table.Static where Element: ~Copyable {
    public enum Positions {
        public typealias View = Property<Hash.Table<Element>.Positions, Hash.Table<Element>.Static<bucketCapacity>>.View.Typed<Element>.Valued<bucketCapacity>
    }
}

extension Hash.Table.Static where Element: ~Copyable {
    /// Access position update operations.
    @inlinable
    public var positions: Positions.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Positions.View = unsafe .init(&self); yield &view }
    }
}

extension Property.View.Typed.Valued
where Tag == Hash.Table<Element>.Positions,
      Base == Hash.Table<Element>.Static<n>,
      Element: ~Copyable
{
    /// Decrements all positions greater than `removedPosition`.
    ///
    /// When an element at `removedPosition` is removed from external storage,
    /// all positions greater than `removedPosition` must be decremented.
    ///
    /// - Parameter removedPosition: The bounded position that was removed.
    @inlinable
    public mutating func decrement(after removedPosition: Index<Element>.Bounded<n>) {
        unsafe base.pointee.decrementAllPositions(after: removedPosition)
    }

    /// Updates the position for an element with the given hash value.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to update.
    ///   - equals: A closure that checks if the element at a given position matches.
    ///   - newPosition: The new bounded position for the element.
    /// - Returns: `true` if the position was updated, `false` if element not found.
    @inlinable
    @discardableResult
    public mutating func update(
        forHash hashValue: Hash.Value,
        equals: (Index<Element>.Bounded<n>) -> Bool,
        newPosition: Index<Element>.Bounded<n>
    ) -> Bool {
        unsafe base.pointee.updatePositionInternal(
            forHash: hashValue, equals: equals, newPosition: newPosition
        )
    }

    /// Updates the position at a specific bucket index.
    ///
    /// - Parameters:
    ///   - bucket: The bucket index to update.
    ///   - newPosition: The new bounded position value.
    ///
    /// - Precondition: The bucket must contain a valid element.
    @inlinable
    public mutating func update(atBucket bucket: Hash.Table<Element>.Bucket.Index, newPosition: Index<Element>.Bounded<n>) {
        unsafe base.pointee.updatePositionInternal(atBucket: bucket, newPosition: newPosition)
    }
}
