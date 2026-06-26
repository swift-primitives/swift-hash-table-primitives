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
import Hash_Indexed_Primitive
import Hash_Primitives
import Hash_Primitives_Standard_Library_Integration
import Buffer_Primitive
import Buffer_Linear_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Cardinal_Primitives

// The engine rows. Carrier for consumer-grade ops: Hash.Indexed over the
// dense heap column (the ordered families' combinator, measured here without
// the family on top). Table-direct rows isolate per-instance costs the
// carrier amortizes: `_seed = makeSeed()` (a SystemRandomNumberGenerator
// read PER INSTANCE — stdlib hashes with one process-global seed) and the
// O(bucketCapacity) metadata fill at init.

typealias DenseColumn =
    Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Int>>.Linear

typealias Indexed = Hash.Indexed<DenseColumn>

extension Bench {
    /// Typed count from a runtime size via the non-throwing `UInt` lane.
    static func count<E>(_ n: Int) -> Index_Primitives.Index<E>.Count {
        Index_Primitives.Index<E>.Count(Cardinal(UInt(n)))
    }

    /// `init.zero` / `init.sized`: per-instance construction — seed syscall +
    /// bucket-metadata fill (O(capacity), quantified by the size axis) vs
    /// `Swift.Set`'s constructors (process-global seed, no per-instance RNG).
    /// `init.firstInsert`: construction + one insert through the carrier.
    /// `build.zero` vs `build.reserved`: insert-to-n with and without growth —
    /// the delta is the total growth + re-seed cost per build (the spike,
    /// amortized over ~log2(n/16) doublings; per-boundary cost derived in doc).
    static func hashTableCases() -> [Result] {
        var results: [Result] = []
        let initReps = 1 << 14

        results.append(Result(
            name: "init.zero", subject: "tower.table", n: 0, opsPerBatch: initReps,
            perOpNs: sample(opsPerBatch: initReps) {
                var alive = 0
                for _ in 0..<initReps {
                    let t = Hash.Table<Int>(minimumCapacity: .zero)
                    alive &+= t.isEmpty ? 1 : 0
                }
                sink(alive)
            }
        ))

        results.append(Result(
            name: "init.zero", subject: "stdlib", n: 0, opsPerBatch: initReps,
            perOpNs: sample(opsPerBatch: initReps) {
                var alive = 0
                for _ in 0..<initReps {
                    let s = Swift.Set<Int>()
                    alive &+= s.isEmpty ? 1 : 0
                }
                sink(alive)
            }
        ))

        for n in sizes {
            let reps = Swift.max(16, (1 << 22) / Swift.max(n, 64))

            results.append(Result(
                name: "init.sized", subject: "tower.table", n: n, opsPerBatch: reps,
                perOpNs: sample(opsPerBatch: reps) {
                    var alive = 0
                    for _ in 0..<reps {
                        let t = Hash.Table<Int>(minimumCapacity: count(n))
                        alive &+= t.isEmpty ? 1 : 0
                    }
                    sink(alive)
                }
            ))

            results.append(Result(
                name: "init.sized", subject: "stdlib", n: n, opsPerBatch: reps,
                perOpNs: sample(opsPerBatch: reps) {
                    var alive = 0
                    for _ in 0..<reps {
                        let s = Swift.Set<Int>(minimumCapacity: n)
                        alive &+= s.isEmpty ? 1 : 0
                    }
                    sink(alive)
                }
            ))
        }

        let firstReps = 1 << 14
        let seed = opaque(7)

        results.append(Result(
            name: "init.firstInsert", subject: "tower.indexed", n: 1, opsPerBatch: firstReps,
            perOpNs: sample(opsPerBatch: firstReps) {
                var acc = 0
                for i in 0..<firstReps {
                    var x = Indexed(minimumCapacity: .zero)
                    acc &+= (x.insert(i &+ seed) == nil) ? 1 : 0
                }
                sink(acc)
            }
        ))

        results.append(Result(
            name: "init.firstInsert", subject: "stdlib", n: 1, opsPerBatch: firstReps,
            perOpNs: sample(opsPerBatch: firstReps) {
                var acc = 0
                for i in 0..<firstReps {
                    var s = Swift.Set<Int>()
                    acc &+= s.insert(i &+ seed).inserted ? 1 : 0
                }
                sink(acc)
            }
        ))

        for n in [1_024, 4_096, 65_536] {
            let reps = Swift.max(1, structureOpsTarget / n)
            let buildOps = reps * n

            results.append(Result(
                name: "build.zero", subject: "tower.indexed", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var x = Indexed(minimumCapacity: .zero)
                        for i in 0..<n { acc &+= (x.insert(i &+ seed) == nil) ? 1 : 0 }
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "build.reserved", subject: "tower.indexed", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var x = Indexed(minimumCapacity: count(n))
                        for i in 0..<n { acc &+= (x.insert(i &+ seed) == nil) ? 1 : 0 }
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "build.zero", subject: "stdlib", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var s = Swift.Set<Int>()
                        for i in 0..<n { acc &+= s.insert(i &+ seed).inserted ? 1 : 0 }
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "build.reserved", subject: "stdlib", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var s = Swift.Set<Int>(minimumCapacity: n)
                        for i in 0..<n { acc &+= s.insert(i &+ seed).inserted ? 1 : 0 }
                    }
                    sink(acc)
                }
            ))
        }

        return results
    }

    /// `evict.{back,front,random}`: steady-state remove(member) + fresh-insert
    /// PAIRS through the carrier at size n — the B-7 evidence rows (engine-fix
    /// arc; ns/pair). A `members` mirror supplies the by-member eviction target
    /// (its `remove(at:)` memmove rides inside the measured pair — disclosed;
    /// it is the same dense shift the family itself pays). The stdlib subject
    /// is the unordered reference (O(1) removes — no order contract).
    static func evictCases() -> [Result] {
        var results: [Result] = []
        var rngState: UInt64 = 0xE71C_7000_0000_0001

        func nextRandom() -> UInt64 {
            rngState &+= 0x9E37_79B9_7F4A_7C15
            var z = rngState
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        for n in [16, 256, 4_096, 65_536] {
            let pairs = Swift.max(512, (1 << 22) / Swift.max(n, 1))

            for direction in ["back", "front", "random"] {
                results.append(Result(
                    name: "evict.\(direction)", subject: "tower.indexed", n: n, opsPerBatch: pairs,
                    perOpNs: {
                        var x = Indexed(minimumCapacity: count(n))
                        var members: [Int] = []
                        var nextKey = opaque(1)
                        for _ in 0..<n {
                            x.insert(nextKey)
                            members.append(nextKey)
                            nextKey &+= 1
                        }
                        return sample(opsPerBatch: pairs) {
                            var acc = 0
                            for _ in 0..<pairs {
                                let k: Int
                                switch direction {
                                case "back": k = members.count - 1
                                case "front": k = 0
                                default: k = Int(nextRandom() % UInt64(members.count))
                                }
                                let member = members[k]
                                acc &+= (x.remove(member) == nil) ? 0 : 1
                                members.remove(at: k)
                                x.insert(nextKey)
                                members.append(nextKey)
                                nextKey &+= 1
                            }
                            sink(acc)
                        }
                    }()
                ))

                results.append(Result(
                    name: "evict.\(direction)", subject: "stdlib", n: n, opsPerBatch: pairs,
                    perOpNs: {
                        var s = Swift.Set<Int>()
                        var members: [Int] = []
                        var nextKey = opaque(1)
                        for _ in 0..<n {
                            s.insert(nextKey)
                            members.append(nextKey)
                            nextKey &+= 1
                        }
                        return sample(opsPerBatch: pairs) {
                            var acc = 0
                            for _ in 0..<pairs {
                                let k: Int
                                switch direction {
                                case "back": k = members.count - 1
                                case "front": k = 0
                                default: k = Int(nextRandom() % UInt64(members.count))
                                }
                                let member = members[k]
                                acc &+= (s.remove(member) == nil) ? 0 : 1
                                members.remove(at: k)
                                s.insert(nextKey)
                                members.append(nextKey)
                                nextKey &+= 1
                            }
                            sink(acc)
                        }
                    }()
                ))
            }
        }

        return results
    }
}
