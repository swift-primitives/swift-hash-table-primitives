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

import Hash_Table_Primitive
public import Hash_Indexed_Primitive
public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
import Hash_Primitives
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration

extension Hash {
    /// THE INDEX-COHERENCE LAWS (seat-ruled, 2026-06-10) — the [DS-024] sibling for the
    /// ordered hashed family: the bucket engine and the dense plane must agree.
    ///
    ///   law 1 — every dense position is findable through the engine;
    ///   law 2 — every live bucket entry's position is a live dense slot whose stored
    ///           hash matches the member at that slot;
    ///   law 3 — the engine's count equals the dense count.
    ///
    /// Every composition of `Hash.Indexed` (direct and `Shared`-wrapped) runs these from
    /// its consuming family's suite.
    public enum Coherence {
        /// Runs the coherence laws over a column populated by `populate` and returns
        /// human-readable descriptions of every violation (empty = coherent).
        public static func violations<E: Hash.Key & Copyable>(
            _ column: borrowing Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>
        ) -> [String] {
            var found: [String] = []
            let end = column.count.map(Ordinal.init)

            // law 1 — every dense position is findable through the engine.
            var slot: Index<E> = .zero
            while slot < end {
                let foundPosition = column.position(of: column[slot])
                if foundPosition != slot {
                    found.append("law 1: the member at dense slot \(slot) resolves to \(String(describing: foundPosition))")
                }
                slot = slot.successor.saturating()
            }

            // law 2 — every live bucket entry's position is a live dense slot whose
            // stored hash matches the member at that slot (the stale-entry detector:
            // a stale entry probes `equals` against a vacated or repurposed dense slot).
            var bucket: Hash.Table<E>.Bucket.Index = .zero
            let bucketEnd = column.indices.bucketCapacity.map(Ordinal.init)
            var liveEntries: Index<E>.Count = .zero
            while bucket < bucketEnd {
                let storedHash = column.indices[hash: bucket]
                if storedHash != Hash.Table<E>.empty {
                    liveEntries += .one
                    let position = column.indices[position: bucket]
                    if position < end {
                        let memberHash = Hash.Table<E>.normalize(column[position].hashValue)
                        if memberHash != storedHash {
                            found.append("law 2: bucket \(bucket) stores hash \(storedHash) but the member at dense slot \(position) hashes to \(memberHash)")
                        }
                    } else {
                        found.append("law 2: bucket \(bucket) holds position \(position) beyond the dense count \(column.count)")
                    }
                }
                bucket = bucket.successor.saturating()
            }

            // law 3 — the ENGINE's count equals the dense count; and (tombstone-free,
            // occupied == count) the live bucket entries are exactly that many.
            if column.indices._count != column.count {
                found.append("law 3: the engine counts \(column.indices._count) but the dense plane holds \(column.count)")
            }
            if liveEntries != column.count {
                found.append("law 3: \(liveEntries) live bucket entries but the dense plane holds \(column.count)")
            }

            // law 4 — every live bucket's rank back-pointer round-trips (the B-7
            // plane: maintained at placement, chain repair, and growth).
            bucket = .zero
            while bucket < bucketEnd {
                if column.indices[hash: bucket] != Hash.Table<E>.empty {
                    let position = column.indices[position: bucket]
                    let back = column.indices[bucketOfRank: position]
                    if back != bucket {
                        found.append("law 4: bucket \(bucket) holds rank \(position) but the back-pointer names bucket \(back)")
                    }
                }
                bucket = bucket.successor.saturating()
            }
            return found
        }
    }
}
