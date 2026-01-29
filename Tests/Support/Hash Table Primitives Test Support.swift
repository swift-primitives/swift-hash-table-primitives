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

public import Hash_Table_Primitives
import Index_Primitives_Test_Support

// MARK: - Hash.Table Convenience Initializers for Testing
//
//extension Hash.Table where Element: ~Copyable {
//    /// Creates a hash table with the specified minimum capacity using Int for convenience.
//    ///
//    /// - Parameter minimumCapacity: The minimum number of elements the table should
//    ///   be able to store without rehashing.
//    ///
//    /// - Warning: This initializer is for testing only. Production code should
//    ///   use the typed `Index<Element>.Count` initializers.
//    @inlinable
//    public init(minimumCapacity: Int) {
//        self.init(minimumCapacity: Index<Element>.Count(Cardinal(UInt(minimumCapacity))))
//    }
//}
//
//// MARK: - Int-based Test Helpers
//
//extension Hash.Table where Element: ~Copyable {
//    /// Inserts a position into the hash table using Int values for test convenience.
//    ///
//    /// - Parameters:
//    ///   - position: The position as an Int (converted to Index<Element>).
//    ///   - hashValue: The hash value of the element.
//    ///   - equals: A closure that checks equality using Int positions.
//    /// - Returns: `true` if inserted, `false` if duplicate found.
//    ///
//    /// - Warning: This method is for testing only.
//    @inlinable
//    @discardableResult
//    public mutating func insert(
//        position: Int,
//        hashValue: Int,
//        equals: (Int) -> Bool
//    ) -> Bool {
//        let typedPosition = Index<Element>(__unchecked: (), Ordinal(UInt(position)))
//        return insert(
//            position: typedPosition,
//            hashValue: hashValue,
//            equals: { equals(Int(bitPattern: $0.position.rawValue)) }
//        )
//    }
//
//    /// Inserts a position without duplicate checking using Int for test convenience.
//    ///
//    /// - Parameters:
//    ///   - position: The position as an Int.
//    ///   - hashValue: The hash value of the element.
//    ///
//    /// - Warning: This method is for testing only.
//    @inlinable
//    public mutating func insert(
//        __unchecked: Void,
//        position: Int,
//        hashValue: Int
//    ) {
//        let typedPosition = Index<Element>(__unchecked: (), Ordinal(UInt(position)))
//        insert(__unchecked: (), position: typedPosition, hashValue: hashValue)
//    }
//
//    /// Looks up a position using Int for test convenience.
//    ///
//    /// - Parameters:
//    ///   - hashValue: The hash value to look up.
//    ///   - equals: A closure that checks equality using Int positions.
//    /// - Returns: The position as Int, or nil if not found.
//    ///
//    /// - Warning: This method is for testing only.
//    @inlinable
//    public mutating func position(
//        forHash hashValue: Int,
//        equals: (Int) -> Bool
//    ) -> Int? {
//        guard let typedPosition = position(
//            forHash: hashValue,
//            equals: { equals(Int(bitPattern: $0.position.rawValue)) }
//        ) else {
//            return nil
//        }
//        return Int(bitPattern: typedPosition.position.rawValue)
//    }
//
//    /// Removes an element using Int for test convenience.
//    ///
//    /// - Parameters:
//    ///   - hashValue: The hash value of the element to remove.
//    ///   - equals: A closure that checks equality using Int positions.
//    /// - Returns: The removed position as Int, or nil if not found.
//    ///
//    /// - Warning: This method is for testing only.
//    @inlinable
//    @discardableResult
//    public mutating func remove(
//        hashValue: Int,
//        equals: (Int) -> Bool
//    ) -> Int? {
//        guard let typedPosition = remove(
//            hashValue: hashValue,
//            equals: { equals(Int(bitPattern: $0.position.rawValue)) }
//        ) else {
//            return nil
//        }
//        return Int(bitPattern: typedPosition.position.rawValue)
//    }
//
//    /// Decrements positions after a removed position using Int for test convenience.
//    ///
//    /// - Parameter removedPosition: The position that was removed, as Int.
//    ///
//    /// - Warning: This method is for testing only.
//    @inlinable
//    public mutating func decrementPositions(after removedPosition: Int) {
//        let typedPosition = Index<Element>(__unchecked: (), Ordinal(UInt(removedPosition)))
//        decrementPositions(after: typedPosition)
//    }
//
//    /// Returns the count as Int for test convenience.
//    ///
//    /// - Warning: This property is for testing only.
//    @inlinable
//    public var intCount: Int {
//        Int(_storage.header.count.rawValue.rawValue)
//    }
//
//    /// Returns the capacity as Int for test convenience.
//    ///
//    /// - Warning: This property is for testing only.
//    @inlinable
//    public var intCapacity: Int {
//        Int(_storage.header.capacity.rawValue.rawValue)
//    }
//}
//
//// MARK: - ForEach with Int Callback
//
//extension Property.View.Typed
//where Tag == Hash.Table<Element>.ForEach, Base == Hash.Table<Element>, Element: ~Copyable {
//    /// Iterates over all occupied buckets with Int positions for test convenience.
//    ///
//    /// - Parameter body: A closure called with bucket index and position as Int.
//    ///
//    /// - Warning: This method is for testing only.
//    @inlinable
//    public func occupied(_ body: (Int, Int) -> Void) {
//        occupied { bucketIdx, position in
//            body(
//                Int(bitPattern: bucketIdx.position.rawValue),
//                Int(bitPattern: position.position.rawValue)
//            )
//        }
//    }
//}
