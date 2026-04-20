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
@testable import Hash_Table_Primitives
import Hash_Table_Primitives_Test_Support

// Test element type for phantom typing
struct TestElement {}

@Suite("Hash.Table Tests")
struct HashIndexTests {

    @Test
    func `Empty hash index`() {
        let index = Hash.Table<TestElement>()
        #expect(index.isEmpty == true)
        let expectedCount: Index<TestElement>.Count = 0
        #expect(index.count == expectedCount)
    }

    @Test
    func `Insert and lookup`() throws {
        var index = Hash.Table<TestElement>()

        // Insert position 0 with hash 42
        let position: Index<TestElement> = 0
        let inserted = index.insert(position: position, hashValue: 42, equals: { _ in false })
        #expect(inserted == true)
        let expectedCount: Index<TestElement>.Count = 1
        #expect(index.count == expectedCount)

        // Lookup should find it
        let found = index.position(forHash: 42, equals: { $0 == position })
        #expect(found == position)

        // Lookup with wrong hash should not find it
        let notFound = index.position(forHash: 99, equals: { _ in true })
        #expect(notFound == nil)
    }

    @Test
    func `Duplicate rejection`() throws {
        var index = Hash.Table<TestElement>()

        let position0: Index<TestElement> = 0
        let position1: Index<TestElement> = 1
        let first = index.insert(position: position0, hashValue: 42, equals: { _ in false })
        #expect(first == true)

        // Same hash, equals returns true → duplicate
        let duplicate = index.insert(position: position1, hashValue: 42, equals: { $0 == position0 })
        #expect(duplicate == false)
        let expectedCount: Index<TestElement>.Count = 1
        #expect(index.count == expectedCount)
    }

    @Test
    func `Removal`() throws {
        var index = Hash.Table<TestElement>()

        let position0: Index<TestElement> = 0
        let position1: Index<TestElement> = 1
        index.insert(position: position0, hashValue: 42, equals: { _ in false })
        index.insert(position: position1, hashValue: 99, equals: { _ in false })
        let expectedCount2: Index<TestElement>.Count = 2
        #expect(index.count == expectedCount2)

        let removed = index.remove(hashValue: 42, equals: { $0 == position0 })
        #expect(removed == position0)
        let expectedCount1: Index<TestElement>.Count = 1
        #expect(index.count == expectedCount1)

        // Should not find removed element
        let notFound = index.position(forHash: 42, equals: { $0 == position0 })
        #expect(notFound == nil)

        // Other element still present
        let stillThere = index.position(forHash: 99, equals: { $0 == position1 })
        #expect(stillThere == position1)
    }

    @Test
    func `Position decrement after removal`() throws {
        var index = Hash.Table<TestElement>()

        // Insert positions 0, 1, 2
        let position0: Index<TestElement> = 0
        let position1: Index<TestElement> = 1
        let position2: Index<TestElement> = 2
        index.insert(position: position0, hashValue: 10, equals: { _ in false })
        index.insert(position: position1, hashValue: 20, equals: { _ in false })
        index.insert(position: position2, hashValue: 30, equals: { _ in false })

        // Remove from external storage at position 1
        index.remove(hashValue: 20, equals: { $0 == position1 })
        index.positions.decrement(after: position1)

        // Position 0 unchanged
        #expect(index.position(forHash: 10, equals: { $0 == position0 }) == position0)

        // Position 2 now at position 1
        #expect(index.position(forHash: 30, equals: { $0 == position1 }) == position1)
    }

    @Test
    func `Growth under load`() throws {
        let initialCapacity: Index<TestElement>.Count = 4
        var index = Hash.Table<TestElement>(minimumCapacity: initialCapacity)
        let initialBucketCapacity = index.capacity

        // Insert enough elements to trigger growth
        for i in 0..<20 {
            let position: Index<TestElement> = Index(Ordinal(UInt(i)))
            let hashValue = Hash.Value(__unchecked: (), Int(bitPattern: position.position.rawValue) * 7)
            index.insert(position: position, hashValue: hashValue, equals: { _ in false })
        }

        let expectedCount: Index<TestElement>.Count = 20
        #expect(index.count == expectedCount)
        #expect(index.capacity > initialBucketCapacity)

        // All elements should still be findable
        for i in 0..<20 {
            let position: Index<TestElement> = Index(Ordinal(UInt(i)))
            let hashValue = Hash.Value(__unchecked: (), Int(bitPattern: position.position.rawValue) * 7)
            #expect(index.position(forHash: hashValue, equals: { $0 == position }) == position)
        }
    }

    @Test
    func `Remove all keeping capacity`() throws {
        var index = Hash.Table<TestElement>()

        for i in 0..<10 {
            let position: Index<TestElement> = Index(Ordinal(UInt(i)))
            let hashValue = Hash.Value(__unchecked: (), Int(bitPattern: position.position.rawValue) * 3)
            index.insert(position: position, hashValue: hashValue, equals: { _ in false })
        }

        let capacityBefore = index.capacity
        index.remove.all(keepingCapacity: true)

        #expect(index.isEmpty == true)
        let expectedCount: Index<TestElement>.Count = 0
        #expect(index.count == expectedCount)
        #expect(index.capacity == capacityBefore)
    }

    @Test
    func `Remove all releasing capacity`() throws {
        let initialCapacity: Index<TestElement>.Count = 100
        var index = Hash.Table<TestElement>(minimumCapacity: initialCapacity)

        for i in 0..<50 {
            let position: Index<TestElement> = Index(Ordinal(UInt(i)))
            let hashValue = Hash.Value(__unchecked: (), Int(bitPattern: position.position.rawValue) * 5)
            index.insert(position: position, hashValue: hashValue, equals: { _ in false })
        }

        index.remove.all(keepingCapacity: false)

        #expect(index.isEmpty == true)
        let expectedCount: Index<TestElement>.Count = 0
        #expect(index.count == expectedCount)
    }

    @Test
    func `Hash collision handling`() throws {
        var index = Hash.Table<TestElement>()

        // Insert multiple elements with the same hash
        let position0: Index<TestElement> = 0
        let position1: Index<TestElement> = 1
        let position2: Index<TestElement> = 2
        index.insert(position: position0, hashValue: 42, equals: { _ in false })
        index.insert(position: position1, hashValue: 42, equals: { _ in false })
        index.insert(position: position2, hashValue: 42, equals: { _ in false })

        let expectedCount: Index<TestElement>.Count = 3
        #expect(index.count == expectedCount)

        // Each should be findable with correct equals
        #expect(index.position(forHash: 42, equals: { $0 == position0 }) == position0)
        #expect(index.position(forHash: 42, equals: { $0 == position1 }) == position1)
        #expect(index.position(forHash: 42, equals: { $0 == position2 }) == position2)
    }

    @Test
    func `Type safety - different element types are distinct`() throws {
        // Hash.Table<TypeA> and Hash.Table<TypeB> are different types
        struct TypeA {}
        struct TypeB {}

        var indexA = Hash.Table<TypeA>()
        var indexB = Hash.Table<TypeB>()

        indexA.insert(position: 0, hashValue: 42, equals: { _ in false })
        indexB.insert(position: 0, hashValue: 42, equals: { _ in false })

        // These are different types - positions cannot be mixed
        // indexA.insert(position: positionB, ...) would be a compile error

        let expectedCountA: Index<TypeA>.Count = 1
        let expectedCountB: Index<TypeB>.Count = 1
        #expect(indexA.count == expectedCountA)
        #expect(indexB.count == expectedCountB)
    }
}
