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

import Testing
import Hash_Primitives
import Index_Primitives
@testable import Hash_Table_Primitives

// Test element type for phantom typing
struct TestElement {}

@Suite("Hash.Table Tests")
struct HashIndexTests {

    @Test("Empty hash index")
    func emptyHashIndex() {
        let index = Hash.Table<TestElement>()
        #expect(index.isEmpty == true)
        #expect(index.count == 0)
    }

    @Test("Insert and lookup")
    func insertAndLookup() {
        var index = Hash.Table<TestElement>()

        // Insert position 0 with hash 42
        let inserted = index.insert(position: 0, hashValue: 42, equals: { _ in false })
        #expect(inserted == true)
        #expect(index.count == 1)

        // Lookup should find it
        let found = index.position(forHash: 42, equals: { $0 == 0 })
        #expect(found == 0)

        // Lookup with wrong hash should not find it
        let notFound = index.position(forHash: 99, equals: { _ in true })
        #expect(notFound == nil)
    }

    @Test("Duplicate rejection")
    func duplicateRejection() {
        var index = Hash.Table<TestElement>()

        let first = index.insert(position: 0, hashValue: 42, equals: { _ in false })
        #expect(first == true)

        // Same hash, equals returns true → duplicate
        let duplicate = index.insert(position: 1, hashValue: 42, equals: { $0 == 0 })
        #expect(duplicate == false)
        #expect(index.count == 1)
    }

    @Test("Removal")
    func removal() {
        var index = Hash.Table<TestElement>()

        index.insert(position: 0, hashValue: 42, equals: { _ in false })
        index.insert(position: 1, hashValue: 99, equals: { _ in false })
        #expect(index.count == 2)

        let removed = index.remove(hashValue: 42, equals: { $0 == 0 })
        #expect(removed == 0)
        #expect(index.count == 1)

        // Should not find removed element
        let notFound = index.position(forHash: 42, equals: { $0 == 0 })
        #expect(notFound == nil)

        // Other element still present
        let stillThere = index.position(forHash: 99, equals: { $0 == 1 })
        #expect(stillThere == 1)
    }

    @Test("Position decrement after removal")
    func positionDecrementAfterRemoval() {
        var index = Hash.Table<TestElement>()

        // Insert positions 0, 1, 2
        index.insert(position: 0, hashValue: 10, equals: { _ in false })
        index.insert(position: 1, hashValue: 20, equals: { _ in false })
        index.insert(position: 2, hashValue: 30, equals: { _ in false })

        // Remove from external storage at position 1
        index.remove(hashValue: 20, equals: { $0 == 1 })
        index.decrementPositions(after: 1)

        // Position 0 unchanged
        #expect(index.position(forHash: 10, equals: { $0 == 0 }) == 0)

        // Position 2 now at position 1
        #expect(index.position(forHash: 30, equals: { $0 == 1 }) == 1)
    }

    @Test("Growth under load")
    func growthUnderLoad() throws {
        var index = Hash.Table<TestElement>(minimumCapacity: 4)
        let initialCapacity = index.capacity

        // Insert enough elements to trigger growth
        for i: Index<TestElement> in try (0..<20).map(Index.init) {
            index.insert(position: i, hashValue: i.position.rawValue * 7, equals: { _ in false })
        }

        #expect(index.count == 20)
        #expect(index.capacity > initialCapacity)

        // All elements should still be findable
        for i: Index<TestElement> in try (0..<20).map(Index.init) {
            #expect(index.position(forHash: i.position.rawValue * 7, equals: { $0 == i }) == i)
        }
    }

    @Test("Remove all keeping capacity")
    func removeAllKeepingCapacity() throws {
        var index = Hash.Table<TestElement>()

        for i: Index<TestElement> in try (0..<10).map(Index.init) {
            index.insert(position: i, hashValue: i.position.rawValue * 3, equals: { _ in false })
        }

        let capacityBefore = index.capacity
        index.removeAll(keepingCapacity: true)

        #expect(index.isEmpty == true)
        #expect(index.count == 0)
        #expect(index.capacity == capacityBefore)
    }

    @Test("Remove all releasing capacity")
    func removeAllReleasingCapacity() throws {
        var index = Hash.Table<TestElement>(minimumCapacity: 100)

        for i: Index<TestElement> in try (0..<50).map(Index.init) {
            index.insert(position: i, hashValue: i.position.rawValue * 5, equals: { _ in false })
        }

        index.removeAll(keepingCapacity: false)

        #expect(index.isEmpty == true)
        #expect(index.count == 0)
    }

    @Test("Hash collision handling")
    func hashCollisionHandling() {
        var index = Hash.Table<TestElement>()

        // Insert multiple elements with the same hash
        index.insert(position: 0, hashValue: 42, equals: { _ in false })
        index.insert(position: 1, hashValue: 42, equals: { _ in false })
        index.insert(position: 2, hashValue: 42, equals: { _ in false })

        #expect(index.count == 3)

        // Each should be findable with correct equals
        #expect(index.position(forHash: 42, equals: { $0 == 0 }) == 0)
        #expect(index.position(forHash: 42, equals: { $0 == 1 }) == 1)
        #expect(index.position(forHash: 42, equals: { $0 == 2 }) == 2)
    }

    @Test("Type safety - different element types are distinct")
    func typeSafety() {
        // Hash.Table<TypeA> and Hash.Table<TypeB> are different types
        struct TypeA {}
        struct TypeB {}

        var indexA = Hash.Table<TypeA>()
        var indexB = Hash.Table<TypeB>()

        indexA.insert(position: 0, hashValue: 42, equals: { _ in false })
        indexB.insert(position: 0, hashValue: 42, equals: { _ in false })

        // These are different types - positions cannot be mixed
        // indexA.insert(position: Index<TypeB>(0), ...) would be a compile error

        #expect(indexA.count == 1)
        #expect(indexB.count == 1)
    }
}
