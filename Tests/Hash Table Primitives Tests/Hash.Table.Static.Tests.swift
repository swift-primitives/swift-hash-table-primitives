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
private struct InlineTestElement {}

@Suite("Hash.Table.Static Tests")
struct HashTableInlineTests {

    @Test("Empty inline hash table")
    func emptyInlineHashTable() {
        let table = Hash.Table<InlineTestElement>.Static<16>()
        #expect(table.isEmpty == true)
        let expectedCount: Index<InlineTestElement>.Count = 0
        #expect(table.count == expectedCount)
        #expect(table.shouldGrow == false)
        #expect(table.isFull == false)
    }

    @Test("Insert and lookup")
    func insertAndLookup() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        // Insert position 0 with hash 42
        let position: Index<InlineTestElement>.Bounded<16> = 0
        let inserted = table.insert(position: position, hashValue: 42, equals: { _ in false })
        #expect(inserted == true)
        let expectedCount: Index<InlineTestElement>.Count = 1
        #expect(table.count == expectedCount)

        // Lookup should find it
        let found = table.position(forHash: 42, equals: { $0 == position })
        #expect(found == position)

        // Lookup with wrong hash should not find it
        let notFound = table.position(forHash: 99, equals: { _ in true })
        #expect(notFound == nil)
    }

    @Test("Duplicate rejection")
    func duplicateRejection() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        let position0: Index<InlineTestElement>.Bounded<16> = 0
        let position1: Index<InlineTestElement>.Bounded<16> = 1
        let first = table.insert(position: position0, hashValue: 42, equals: { _ in false })
        #expect(first == true)

        // Same hash, equals returns true → duplicate
        let duplicate = table.insert(position: position1, hashValue: 42, equals: { $0 == position0 })
        #expect(duplicate == false)
        let expectedCount: Index<InlineTestElement>.Count = 1
        #expect(table.count == expectedCount)
    }

    @Test("Removal with tombstone")
    func removalWithTombstone() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        let position0: Index<InlineTestElement>.Bounded<16> = 0
        let position1: Index<InlineTestElement>.Bounded<16> = 1
        table.insert(position: position0, hashValue: 42, equals: { _ in false })
        table.insert(position: position1, hashValue: 99, equals: { _ in false })
        let expectedCount2: Index<InlineTestElement>.Count = 2
        #expect(table.count == expectedCount2)

        let removed = table.remove(hashValue: 42, equals: { $0 == position0 })
        #expect(removed == position0)
        let expectedCount1: Index<InlineTestElement>.Count = 1
        #expect(table.count == expectedCount1)

        // Should not find removed element
        let notFound = table.position(forHash: 42, equals: { $0 == position0 })
        #expect(notFound == nil)

        // Other element still present
        let stillThere = table.position(forHash: 99, equals: { $0 == position1 })
        #expect(stillThere == position1)
    }

    @Test("Position decrement after removal")
    func positionDecrementAfterRemoval() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        // Insert positions 0, 1, 2
        let position0: Index<InlineTestElement>.Bounded<16> = 0
        let position1: Index<InlineTestElement>.Bounded<16> = 1
        let position2: Index<InlineTestElement>.Bounded<16> = 2
        table.insert(position: position0, hashValue: 10, equals: { _ in false })
        table.insert(position: position1, hashValue: 20, equals: { _ in false })
        table.insert(position: position2, hashValue: 30, equals: { _ in false })

        // Remove from external storage at position 1
        table.remove(hashValue: 20, equals: { $0 == position1 })
        table.positions.decrement(after: position1)

        // Position 0 unchanged
        #expect(table.position(forHash: 10, equals: { $0 == position0 }) == position0)

        // Position 2 now at position 1
        #expect(table.position(forHash: 30, equals: { $0 == position1 }) == position1)
    }

    @Test("Capacity limits - cannot grow")
    func capacityLimits() throws {
        var table = Hash.Table<InlineTestElement>.Static<8>()
        // 8 buckets at 70% → ~5 elements before shouldGrow

        // Fill up to capacity
        for i in 0..<8 {
            let position: Index<InlineTestElement>.Bounded<8> = .init(Index<InlineTestElement>(Ordinal(UInt(i))))!
            let hashValue: Hash.Value = Hash.Value(__unchecked: (), i * 17 + 1) // Unique hashes
            let result = table.insert(position: position, hashValue: hashValue, equals: { _ in false })
            // First 5 should succeed easily, then depends on load factor
            if i < 5 {
                #expect(result == true, "Insert \(i) should succeed")
            }
        }

        // Table should be full or nearly full
        #expect(table.isFull == true || table.shouldGrow == true)
    }

    @Test("Remove all")
    func removeAll() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        for i in 0..<10 {
            let position: Index<InlineTestElement>.Bounded<16> = .init(Index<InlineTestElement>(Ordinal(UInt(i))))!
            let hashValue: Hash.Value = Hash.Value(__unchecked: (), i * 3)
            table.insert(position: position, hashValue: hashValue, equals: { _ in false })
        }

        table.remove.all()

        #expect(table.isEmpty == true)
        let expectedCount: Index<InlineTestElement>.Count = 0
        #expect(table.count == expectedCount)
        let expectedOccupied: Hash.Table<InlineTestElement>.Static<16>.BucketIndex.Count = 0
        #expect(table.occupancy == expectedOccupied)
    }

    @Test("Hash collision handling")
    func hashCollisionHandling() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        // Insert multiple elements with the same hash
        let position0: Index<InlineTestElement>.Bounded<16> = 0
        let position1: Index<InlineTestElement>.Bounded<16> = 1
        let position2: Index<InlineTestElement>.Bounded<16> = 2
        table.insert(position: position0, hashValue: 42, equals: { _ in false })
        table.insert(position: position1, hashValue: 42, equals: { _ in false })
        table.insert(position: position2, hashValue: 42, equals: { _ in false })

        let expectedCount: Index<InlineTestElement>.Count = 3
        #expect(table.count == expectedCount)

        // Each should be findable with correct equals
        #expect(table.position(forHash: 42, equals: { $0 == position0 }) == position0)
        #expect(table.position(forHash: 42, equals: { $0 == position1 }) == position1)
        #expect(table.position(forHash: 42, equals: { $0 == position2 }) == position2)
    }

    @Test("Rehash removes tombstones")
    func rehashRemovesTombstones() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        // Insert 5 elements
        for i in 0..<5 {
            let position: Index<InlineTestElement>.Bounded<16> = .init(Index<InlineTestElement>(Ordinal(UInt(i))))!
            table.insert(position: position, hashValue: Hash.Value(__unchecked: (), i * 7), equals: { _ in false })
        }

        // Remove 3 elements (creates tombstones)
        for i in 0..<3 {
            let position: Index<InlineTestElement>.Bounded<16> = .init(Index<InlineTestElement>(Ordinal(UInt(i))))!
            table.remove(hashValue: Hash.Value(__unchecked: (), i * 7), equals: { $0 == position })
        }

        let occupiedBefore = table.occupancy
        table.rehash()
        let occupiedAfter = table.occupancy

        // Occupied should decrease (tombstones removed)
        #expect(occupiedAfter < occupiedBefore)

        // Remaining elements should still be findable
        let position3: Index<InlineTestElement>.Bounded<16> = 3
        let position4: Index<InlineTestElement>.Bounded<16> = 4
        let hash3: Hash.Value = Hash.Value(__unchecked: (), 3 * 7)
        let hash4: Hash.Value = Hash.Value(__unchecked: (), 4 * 7)
        #expect(table.position(forHash: hash3, equals: { $0 == position3 }) == position3)
        #expect(table.position(forHash: hash4, equals: { $0 == position4 }) == position4)
    }

    @Test("ForEach iteration")
    func forEachIteration() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        // Insert 5 elements
        for i in 0..<5 {
            let position: Index<InlineTestElement>.Bounded<16> = .init(Index<InlineTestElement>(Ordinal(UInt(i))))!
            table.insert(position: position, hashValue: Hash.Value(__unchecked: (), i * 11), equals: { _ in false })
        }

        // Collect positions via forEach
        var positions: [Index<InlineTestElement>.Bounded<16>] = []
        table.forEach.position { positions.append($0) }

        #expect(positions.count == 5)

        // All original positions should be present
        for i in 0..<5 {
            let position: Index<InlineTestElement>.Bounded<16> = .init(Index<InlineTestElement>(Ordinal(UInt(i))))!
            #expect(positions.contains(position))
        }
    }

    @Test("Update position")
    func updatePosition() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        let position0: Index<InlineTestElement>.Bounded<16> = 0
        let position5: Index<InlineTestElement>.Bounded<16> = 5
        table.insert(position: position0, hashValue: 42, equals: { _ in false })

        // Update position from 0 to 5
        let updated = table.positions.update(forHash: 42, equals: { $0 == position0 }, newPosition: position5)
        #expect(updated == true)

        // Now findable at position 5
        #expect(table.position(forHash: 42, equals: { $0 == position5 }) == position5)
        // Not at position 0
        #expect(table.position(forHash: 42, equals: { $0 == position0 }) == nil)
    }

    @Test("Contains check")
    func containsCheck() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        let position: Index<InlineTestElement>.Bounded<16> = 0
        table.insert(position: position, hashValue: 42, equals: { _ in false })

        #expect(table.contains(hashValue: 42, equals: { $0 == position }) == true)
        #expect(table.contains(hashValue: 99, equals: { _ in true }) == false)
    }

    @Test("Unchecked insert")
    func uncheckedInsert() throws {
        var table = Hash.Table<InlineTestElement>.Static<16>()

        let position0: Index<InlineTestElement>.Bounded<16> = 0
        let position1: Index<InlineTestElement>.Bounded<16> = 1

        let result1 = table.insert(__unchecked: (), position: position0, hashValue: 42)
        #expect(result1 == true)

        let result2 = table.insert(__unchecked: (), position: position1, hashValue: 99)
        #expect(result2 == true)

        let expectedCount: Index<InlineTestElement>.Count = 2
        #expect(table.count == expectedCount)
    }

    @Test("Copyable when Element is Copyable")
    func copyableWhenElementCopyable() throws {
        var table = Hash.Table<Int>.Static<16>()
        let pos0: Index<Int>.Bounded<16> = 0
        let pos1: Index<Int>.Bounded<16> = 1
        table.insert(position: pos0, hashValue: 42, equals: { _ in false })

        // Should be copyable
        let copy = table
        #expect(copy.count == table.count)

        // Modifications to original don't affect copy (value semantics)
        table.insert(position: pos1, hashValue: 99, equals: { _ in false })
        let expectedCount1: Index<Int>.Count = 1
        let expectedCount2: Index<Int>.Count = 2
        #expect(copy.count == expectedCount1)
        #expect(table.count == expectedCount2)
    }
}
