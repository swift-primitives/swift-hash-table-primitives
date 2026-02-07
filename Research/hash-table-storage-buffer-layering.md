# Hash Table Storage-Buffer Layering

<!--
---
version: 1.0.0
last_updated: 2026-02-06
status: IN_PROGRESS
research_tier: 2
applies_to: [swift-hash-table-primitives, swift-buffer-primitives, swift-storage-primitives]
normative: false
---
-->

## Context

`Hash.Table<Element>` (hash-table-primitives) is an open-addressed hash table that manages its own memory via a custom `Storage` class inheriting from `ManagedBuffer<Header, Int>`. This stands apart from the ecosystem's canonical pattern where data structures delegate element lifecycle to `Storage<Element>.Heap` (from storage-primitives) and buffer discipline to `Buffer.Linear`, `Buffer.Ring`, or `Buffer.Slab` (from buffer-primitives).

**Trigger**: [RES-001] Investigation — should `Hash.Table.Storage` be replaced with a buffer from buffer-primitives?

**Scope**: Per [RES-002a], this is a cross-package investigation: the decision affects hash-table-primitives, and the answer depends on the capabilities of buffer-primitives, bit-vector-primitives, and storage-primitives.

## Question

Should `Hash.Table`'s internal `Storage : ManagedBuffer<Header, Int>` be replaced with a buffer from buffer-primitives, and if so, which buffer discipline (Linear, Ring, Slab) matches the hash table's access pattern?

## Analysis

### Current Hash.Table Storage Design

`Hash.Table.Storage` at `Hash.Table.swift:104-172`:

```swift
package final class Storage: ManagedBuffer<Header, Int> {
    package static func create(capacity: Index<Bucket>.Count) -> Storage
    package var hashesPointer: UnsafeMutablePointer<Int>
    package var positionsPointer: UnsafeMutablePointer<Int>
    package func readHash(at bucket: BucketIndex) -> Int
    package func readPosition(at bucket: BucketIndex) -> Index<Element>
    package func writeHash(at bucket: BucketIndex, value: Int)
    package func writePosition(at bucket: BucketIndex, value: Index<Element>)
}
```

**Key characteristics**:
1. **Dual-array layout**: A single allocation holds `[hashes...][positions...]` — two logically separate arrays of `Int`, packed contiguously
2. **Element type is `Int`**: Both hashes and positions are stored as `Int`. The `Element` phantom type parameterizes `Hash.Table`, not `Storage`
3. **Power-of-two capacity**: Always a power of two for fast modulo via bitmasking
4. **No initialization tracking**: All slots are initialized at creation (`repeating: 0`). The sentinel `0` means "empty"
5. **No growth tracking**: Growth is handled at the `Hash.Table` level, not in Storage
6. **No element lifecycle**: `Int` is trivial — no `deinit`, no move semantics, no `~Copyable` concerns
7. **Reference semantics**: `final class` (ARC-managed, single owner)

### The Ecosystem's Canonical Layering Pattern

From the storage-primitives comparative analysis (§3.2), the canonical pattern is:

```
Collection/ADT (Stack, Queue, Set.Ordered)
        ↓ uses
Buffer (Linear, Ring, Slab)
        ↓ uses
Storage (Heap, Inline)
        ↓ uses
Pointer (UnsafeMutablePointer<T>)
```

Real implementations vary:

| Data Structure | Uses Buffer? | Uses Storage? | Notes |
|---------------|-------------|--------------|-------|
| Stack | No | Yes (Storage.Heap) | Implicit linear discipline |
| Queue | Buffer.Ring.Header | Custom ManagedBuffer | Ring discipline via header |
| Set.Ordered | No | Yes (Storage) + Hash.Table | Two independent stores |

**Observation**: Not every data structure follows the full stack. Stack skips Buffer and goes directly to Storage. Queue uses Buffer.Ring.Header but creates its own ManagedBuffer. Set.Ordered composes Storage + Hash.Table side-by-side. The pattern is a guideline, not a rigid requirement.

### What Hash.Table Stores vs What Buffers Manage

The fundamental mismatch:

| Aspect | Hash.Table.Storage | Buffer.Linear/Ring/Slab |
|--------|-------------------|------------------------|
| **Element type** | `Int` (trivial) | `Element: ~Copyable` (arbitrary) |
| **Initialization** | All slots always initialized (sentinel = 0) | Tracks init/deinit lifecycle |
| **Layout** | Dual-array: `[hashes...][positions...]` | Single-array: `[elements...]` |
| **Occupancy** | Tracked via sentinels (0 = empty, Int.min = deleted) | Tracked via count/header/bitmap |
| **Growth** | Table-level (create new, rehash all) | Buffer-level (grow, copy) |
| **Access pattern** | Random (hash → bucket → probe) | Sequential (Linear), circular (Ring), sparse (Slab) |

### Option A: Replace Storage with Buffer.Linear

Use two `Buffer.Linear` instances — one for hashes, one for positions.

```swift
public struct Table<Element: ~Copyable>: ~Copyable {
    var _hashes: Buffer.Linear    // of Int
    var _positions: Buffer.Linear // of Int
}
```

**Problems**:
1. **Two heap allocations** instead of one. Buffer.Linear wraps `Storage<Int>.Heap`, each with its own `ManagedBuffer`. The current design uses a single allocation for both arrays
2. **Unnecessary initialization tracking**. Buffer.Linear tracks `count` and initialization state. Hash.Table needs all slots always initialized with sentinels — no lifecycle tracking needed
3. **Growth mismatch**. Buffer.Linear grows by appending. Hash.Table grows by creating a completely new table and rehashing all entries — the old buffer would be discarded entirely, not grown in-place
4. **API overhead**. Buffer.Linear provides `append`, `consumeFront`, `removeLast` — none of which apply to a hash table. The relevant operation is random access by bucket index

**Verdict**: Poor fit. Buffer.Linear's append-based discipline is the opposite of hash table random access.

### Option B: Replace Storage with Buffer.Slab

Use a `Buffer.Slab` — sparse, index-addressed slots with bitmap tracking.

```swift
public struct Table<Element: ~Copyable>: ~Copyable {
    var _hashes: Buffer.Slab     // of Int, bitmap = occupancy
    var _positions: Buffer.Slab  // of Int, bitmap = occupancy
}
```

**Better fit than Linear**:
- Slab supports random-access insert/remove at arbitrary indices
- Bitmap tracking aligns with the concept of "occupied" vs "empty" buckets
- No assumption of sequential access

**Problems**:
1. **Still two heap allocations** instead of one
2. **Redundant occupancy tracking**. Slab uses `Bit.Vector` to track which slots are occupied. Hash.Table already tracks this via sentinel values (0 = empty, Int.min = deleted). Adding bitmap tracking on top of sentinels is pure overhead — they encode the same information
3. **No tombstone concept**. Slab has a binary state: occupied or vacant. Hash.Table needs a ternary state: empty / occupied / deleted (tombstone). The tombstone is essential for linear probing correctness — removing it breaks probe chains
4. **Slab manages `~Copyable` lifecycle**. Hash.Table stores `Int`, which needs no lifecycle management. The `~Copyable` tracking machinery (deinit iteration, move semantics) is dead weight
5. **Slab expects `Element: ~Copyable`**. Hash.Table's element type is `Int` (always Copyable). The `Element` phantom type on `Hash.Table<Element>` parameterizes the *positions* (what the indices point to), not the stored values

**Verdict**: Closer, but the sentinel-based ternary state, dual-array layout, and trivial element type make Slab a poor semantic fit.

### Option C: Replace Storage with Buffer.Slab + Bit.Vector (Custom)

Use `Bit.Vector` from bit-vector-primitives directly for occupancy, replacing sentinels.

```swift
public struct Table<Element: ~Copyable>: ~Copyable {
    var _hashes: Storage<Int>.Heap    // raw hash values
    var _positions: Storage<Int>.Heap // raw positions
    var _occupancy: Bit.Vector        // which buckets are occupied
    var _deleted: Bit.Vector          // which buckets are tombstones
}
```

**Analysis**:
- Replaces sentinel encoding with explicit bitmaps
- Eliminates sentinel-collision normalization (`0` and `Int.min` no longer special)
- Enables hardware `popcount` for fast count
- Enables efficient iteration via set-bit enumeration

**Problems**:
1. **Four separate allocations** (two Storage.Heap + two Bit.Vector) instead of one
2. **More memory** for small tables: two Bit.Vectors at `ceil(capacity/64) × 8` bytes each, vs zero overhead for sentinel encoding
3. **Sentinel normalization is cheap**: The `normalize()` function is 2 branches — the "problem" it solves is marginal
4. **Breaks the existing API contract**: All current users depend on the sentinel protocol
5. **No functional gain**: The current sentinel approach is correct, tested, and performant. The bitmap approach trades one correct encoding for another

**Verdict**: Technically possible but net negative. Trades a simple, proven sentinel encoding for a more complex multi-allocation scheme without meaningful benefit.

### Option D: Keep Current Design (No Change)

Keep `Hash.Table.Storage : ManagedBuffer<Header, Int>` as-is.

**Arguments for**:
1. **Single allocation**: One `ManagedBuffer` for header + hashes + positions. Optimal memory locality
2. **Trivial element type**: `Int` has no lifecycle — no `~Copyable` concerns, no deinit, no move semantics. The entire buffer/storage machinery exists to solve problems Hash.Table doesn't have
3. **Sentinel-based state is correct**: Ternary state (empty/occupied/deleted) encoded in the hash value is a classic, proven technique for open-addressed hash tables. It's used in CPython's `dict`, Rust's `hashbrown`, Go's `map`, and abseil's `flat_hash_map`
4. **Dual-array layout is deliberate**: Separating hashes from positions enables cache-friendly scanning of hashes during probing (only positions are touched on match). This layout optimization would be lost if each bucket were stored as a `(hash, position)` tuple in a buffer
5. **Hash table growth is incompatible with buffer growth**: Buffer growth policies (doubling, copying existing elements) assume the old elements remain valid. Hash table growth requires complete rehashing — every entry must be re-probed into the new table. No buffer growth policy handles this
6. **Pattern precedent**: Queue also creates its own custom `ManagedBuffer` subclass rather than using `Storage.Heap` directly. This is an established pattern in the ecosystem when the data structure's internal requirements diverge from the generic storage contract

**What about the Static variant?**

`Hash.Table.Static<let bucketCapacity: Int>` already follows the inline pattern:
```swift
var _hashes: InlineArray<bucketCapacity, Int>
var _positions: InlineArray<bucketCapacity, Int>
```

This mirrors `Storage<Element>.Inline<capacity>` in spirit (stack-allocated, compile-time capacity) but appropriately uses `InlineArray<N, Int>` directly rather than `Storage<Int>.Inline<capacity>`, because:
- `Storage.Inline` uses `@_rawLayout` and tracks per-slot initialization via `Bit.Vector.Static<4>` — 32 bytes of tracking overhead for slots that are *always initialized* with sentinels
- `InlineArray` is the stdlib's native fixed-capacity inline array — it's what `Storage.Inline` itself is built on

### Why Hash.Table Is Not a Storage-Buffer-ADT Type

The storage→buffer→ADT pattern serves types that need to **manage element lifecycle** (initialization, deinitialization, move semantics) over **dynamically occupied** slots with **growth discipline** (linear append, ring wrap, slab insert/remove).

Hash.Table does none of these:

| Concern | Storage→Buffer→ADT | Hash.Table |
|---------|-------------------|------------|
| Element lifecycle | Yes — `~Copyable` elements need init/deinit/move | No — stores `Int`, always trivial |
| Dynamic occupancy | Yes — count tracks how many slots are "alive" | No — all slots always initialized with sentinel |
| Growth discipline | Yes — append to end, push to ring, insert in slab | No — growth = complete rebuild via rehash |
| Access pattern | Sequential, circular, or sparse | Random probe sequences |
| Stored values | The elements themselves | *Indices into* external element storage |

Hash.Table is an **index structure** (maps hash values to positions in external storage), not a **container** (owns elements). The storage-buffer-ADT pattern is for containers. Index structures manage their own internal representation because their requirements are fundamentally different.

This is exactly like how a B-tree's internal node structure wouldn't use `Buffer.Linear` — the access pattern (binary search within a node, split/merge between nodes) doesn't match any buffer discipline.

### Comparison with Set.Ordered

Set.Ordered illustrates the correct decomposition:

```
Set.Ordered
├── elementStorage: Storage<Element>    ← Container concern: owns elements
└── hashTable: Hash.Table<Element>      ← Index concern: maps hash→position
```

`elementStorage` follows the storage-buffer pattern (elements need lifecycle management). `hashTable` manages its own internal representation (sentinel-based, dual-array, hash-aware). **They serve different roles and correctly use different patterns.**

If Hash.Table delegated to Buffer, it would be an index structure pretending to be a container. The abstraction boundary would be at the wrong level.

## Outcome

**Status**: IN_PROGRESS

### Preliminary Finding

Hash.Table's `Storage : ManagedBuffer<Header, Int>` **should NOT be replaced** with a buffer from buffer-primitives.

**Rationale**:

1. **Hash.Table is an index structure, not a container**. It stores `Int` hash values and `Int` positions — trivial types with no lifecycle. The buffer-primitives machinery (initialization tracking, `~Copyable` element support, growth policies) solves problems that don't exist for Hash.Table

2. **The dual-array, single-allocation layout is optimal**. Splitting into two buffers doubles heap allocations and loses cache locality. No buffer type supports the dual-array-in-one-allocation pattern

3. **Sentinel-based state is the correct encoding**. Hash tables need ternary state (empty/occupied/deleted). This is encoded naturally in the hash value with zero overhead. Buffer occupancy tracking (bitmap or count) adds overhead to encode the same information differently

4. **Growth semantics are incompatible**. Buffer growth preserves existing elements. Hash table growth requires complete rehashing. No buffer growth policy can express this

5. **Ecosystem precedent**. Queue similarly creates its own `ManagedBuffer` subclass. Custom storage for specialized data structures is an established pattern

### What This Research Clarifies About the Pattern

The storage→buffer→data structure→ADT layering pattern applies to **container types that own elements**:

| Type | Owns elements? | Uses Storage/Buffer? | Correct? |
|------|---------------|---------------------|----------|
| Stack | Yes | Storage.Heap | Yes |
| Queue | Yes | Custom ManagedBuffer + Buffer.Ring.Header | Yes |
| Set.Ordered | Yes (via elementStorage) | Storage + Hash.Table (side-by-side) | Yes |
| Hash.Table | No (stores indices) | Own ManagedBuffer | Yes |
| Buffer.Linear/Ring/Slab | Yes | Storage.Heap / Storage.Inline | Yes |

**Hash.Table is a leaf dependency** — it is consumed by container types (Set.Ordered, Dictionary.Ordered) alongside their element storage. It should not itself consume the storage-buffer stack.

### Open Questions

1. **Should Hash.Table.Storage be renamed?** The name `Storage` conflicts with the ecosystem's `Storage<Element>` from storage-primitives, even though they are in different namespaces. Options:
   - Keep `Storage` (namespaced as `Hash.Table.Storage`, no actual conflict)
   - Rename to `Allocation` or `Backing` or `Buckets` to clarify it's not the same pattern
   - No action needed — the nesting makes the distinction clear

2. **Should Hash.Table gain `Memory.Contiguous.Protocol` conformance?** The dual-array layout could expose spans for bulk operations. This is orthogonal to the storage-buffer question.

3. **Could future Hash.Table variants benefit from Bit.Vector?** A Swiss-table-style SIMD probing design would use metadata bytes instead of sentinels. If we ever move to that design, `Bit.Vector` or a byte-vector could become relevant — but that would be a complete redesign, not a buffer substitution.

## References

- Storage-primitives comparative analysis: `/Users/coen/Developer/swift-primitives/Research/storage-primitives-comparative-analysis.md`
- Inline hash table research: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Research/inline-hash-table.md`
- `Hash.Table.swift`: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.swift`
- Buffer primitives core: `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift`
- Storage primitives: `/Users/coen/Developer/swift-primitives/swift-storage-primitives/`
- CPython dict implementation: Objects/dictobject.c (sentinel-based open addressing)
- Rust hashbrown: Swiss-table SIMD probing with control bytes
- abseil flat_hash_map: Swiss-table variant
