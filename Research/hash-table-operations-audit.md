# Hash Table Operations Audit

<!--
---
version: 1.0.0
last_updated: 2026-02-16
status: RECOMMENDATION
tier: 1
---
-->

## Context

Proactive audit of swift-hash-table-primitives to inventory all public operations and compare against canonical Hash Table operations.

**Trigger**: [RES-012] Discovery -- proactive operations audit across 13 data structure packages.
**Scope**: Package-specific (swift-hash-table-primitives).

## Question

Does swift-hash-table-primitives provide the canonical operations expected of the Hash Table ADT?

## Canonical Operations (ADT Reference)

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| insert(k, v) | O(1) avg, O(n) worst | Insert key-value pair |
| lookup(k) | O(1) avg, O(n) worst | Find value by key |
| delete(k) | O(1) avg, O(n) worst | Remove by key |
| contains(k) | O(1) avg, O(n) worst | Check key existence |
| rehash/grow | O(n) | Resize and rehash |
| iterate | O(n) | Visit all entries |
| count/size | O(1) | Number of entries |
| isEmpty | O(1) | Empty check |
| load_factor | O(1) | Occupancy ratio |

## Current Operations Inventory

**Design note**: `Hash.Table` is not a standalone dictionary. It is an *index structure* -- it maps `Hash.Value` to typed positions (`Index<Element>`) in external storage (e.g., `Set.Ordered`'s element array). Consequently, operations accept explicit hash values and equality closures rather than keys directly. The `(k, v)` in the canonical ADT maps to `(hashValue, position)` in this package.

Two modules are provided:
- **Hash Table Primitives Core** -- `package`-scoped internal operations and type definitions
- **Hash Table Primitives** -- `public` consumer-facing API with Property.View ergonomics

Two variants exist:
- **`Hash.Table<Element>`** -- heap-allocated, dynamic capacity, auto-growing
- **`Hash.Table.Static<let bucketCapacity: Int>`** -- inline (stack) storage, fixed compile-time capacity

### Core Type (`Hash.Table<Element>` -- dynamic)

| Canonical Operation | Method/Property | Complexity | Source File |
|---------------------|-----------------|------------|-------------|
| insert(k, v) | `mutating func insert(position:hashValue:equals:) -> Bool` | O(1) avg, O(n) worst | `Hash.Table+Insertion.swift` (L15-79) |
| insert(k, v) unchecked | `mutating func insert(__unchecked:position:hashValue:)` | O(1) avg, O(n) worst | `Hash.Table+Insertion.swift` (L81-117) |
| lookup(k) | `borrowing func position(forHash:equals:) -> Index<Element>?` | O(1) avg, O(n) worst | `Hash.Table+Lookup.swift` (L14-54) |
| lookup(k) bucket | `borrowing func bucketIndex(forHash:equals:) -> BucketIndex?` | O(1) avg, O(n) worst | `Hash.Table+Lookup.swift` (L56-96) |
| delete(k) | `mutating func remove(hashValue:equals:) -> Index<Element>?` | O(1) avg, O(n) worst | `Hash.Table+Removal.swift` (L20-42) |
| delete(k) at bucket | `mutating func remove(at:)` | O(1) | `Hash.Table+Removal.swift` (L44-55) |
| delete all | `remove.all(keepingCapacity:)` | O(n) | `Hash.Table+Removal.swift` (L71-93) |
| rehash/grow | `mutating func grow()` (internal) | O(n) | `Hash.Table+Insertion.swift` (L119-155) |
| iterate | `var occupied: Hash.Occupied<Element>.View` | O(n) | `Hash.Table+occupied.swift` (L12-34) |
| iterate (forEach) | `forEach.occupied { bucket, position in }` | O(n) | `Hash.Table+ForEach.swift` (L31-51) |
| count/size | `var count: Index<Element>.Count` | O(1) | `Hash.Table+Properties.swift` (L14-19) |
| isEmpty | `var isEmpty: Bool` | O(1) | `Hash.Table+Properties.swift` (L21-25) |
| capacity | `var capacity: Index<Bucket>.Count` | O(1) | `Hash.Table+Properties.swift` (L27-31) |
| load_factor (threshold) | `var shouldGrow: Bool` (internal) | O(1) | `Hash.Table+Properties.swift` (L33-39) |
| **contains(k)** | **MISSING** | -- | -- |
| **load_factor (value)** | **MISSING** | -- | -- |
| **rehash (compact)** | **MISSING** | -- | -- |

### Static Variant (`Hash.Table.Static<let bucketCapacity: Int>`)

| Canonical Operation | Method/Property | Complexity | Source File |
|---------------------|-----------------|------------|-------------|
| insert(k, v) | `mutating func insert(position:hashValue:equals:) -> Bool` | O(1) avg, O(n) worst | `Hash.Table.Static+Insertion.swift` (L12-84) |
| insert(k, v) unchecked | `mutating func insert(__unchecked:position:hashValue:) -> Bool` | O(1) avg, O(n) worst | `Hash.Table.Static+Insertion.swift` (L86-130) |
| lookup(k) | `borrowing func position(forHash:equals:) -> Index<Element>.Bounded<N>?` | O(1) avg, O(n) worst | `Hash.Table.Static+Lookup.swift` (L12-53) |
| lookup(k) bucket | `borrowing func bucketIndex(forHash:equals:) -> BucketIndex?` | O(1) avg, O(n) worst | `Hash.Table.Static+Lookup.swift` (L55-90) |
| contains(k) | `borrowing func contains(hashValue:equals:) -> Bool` | O(1) avg, O(n) worst | `Hash.Table.Static+Lookup.swift` (L92-106) |
| delete(k) | `mutating func remove(hashValue:equals:) -> Index<Element>.Bounded<N>?` | O(1) avg, O(n) worst | `Hash.Table.Static+Removal.swift` (L12-39) |
| delete(k) at bucket | `mutating func remove(atBucket:) -> Index<Element>.Bounded<N>` | O(1) | `Hash.Table.Static+Removal.swift` (L41-58) |
| delete all | `clearAll()` (package) / `remove.all()` (public) | O(n) | `Hash.Table.Static+Removal.swift` (L60-68) / `Hash.Table.Static+Removal.swift` (public, L30-43) |
| rehash (compact) | `mutating func rehash()` | O(n) | `Hash.Table.Static+Removal.swift` (L70-108) |
| iterate (occupied view) | `var occupied: Hash.Occupied<Element>.Static<N>` | O(n) | `Hash.Table.Static+occupied.swift` (L12-31) |
| iterate (forEach) | `forEach.occupied { bucket, position in }` | O(n) | `Hash.Table.Static+ForEach.swift` (public, L33-55) |
| iterate (positions) | `forEach.position { position in }` | O(n) | `Hash.Table.Static+ForEach.swift` (public, L33-55) |
| iterate (early exit) | `eachOccupiedWhile { bucket, hash, position in }` (package) | O(n) | `Hash.Table.Static+ForEach.swift` (Core, L50-76) |
| count/size | `var count: Index<Element>.Count` | O(1) | `Hash.Table.Static+Properties.swift` (L15) |
| isEmpty | `var isEmpty: Bool` | O(1) | `Hash.Table.Static+Properties.swift` (L19) |
| occupancy | `var occupancy: BucketIndex.Count` | O(1) | `Hash.Table.Static+Properties.swift` (L23) |
| capacity | `var capacity: BucketIndex.Count` | O(1) | `Hash.Table.Static+Properties.swift` (L27-29) |
| load_factor (threshold) | `var shouldGrow: Bool` | O(1) | `Hash.Table.Static+Properties.swift` (L31-41) |
| full check | `var isFull: Bool` | O(1) | `Hash.Table.Static+Properties.swift` (L43-49) |
| **load_factor (value)** | **MISSING** | -- | -- |

### Hash.Occupied (Occupied Slot Tracking)

`Hash.Occupied<Source>` is a value type representing a single occupied bucket from a hash table scan. It carries the bucket index, stored hash, and typed position.

| Item | Type | Access | Source File |
|------|------|--------|-------------|
| `Hash.Occupied<Source>` | struct | public | `Hash.Occupied.swift` |
| `.bucket: BucketIndex` | stored property | public | `Hash.Occupied.swift` (L21) |
| `.hash: Int` | stored property | public | `Hash.Occupied.swift` (L24) |
| `.position: Index<Source>` | stored property | public | `Hash.Occupied.swift` (L27) |

**Iteration views** (yield `Hash.Occupied` elements):

| View Type | Variant | Conforms To | Source File |
|-----------|---------|-------------|-------------|
| `Hash.Occupied<Source>.View` | Heap (pointer-based) | `Sequence.Protocol`, `Swift.Sequence` | `Hash.Occupied.View.swift`, `Hash.Occupied.View+Sequence.Protocol.swift` |
| `Hash.Occupied<Source>.View.Iterator` | Heap | `Sequence.Iterator.Protocol`, `IteratorProtocol` | `Hash.Occupied.View.Iterator.swift` |
| `Hash.Occupied<Source>.Static<N>` | Inline (copy-based) | `Sequence.Protocol`, `Swift.Sequence` | `Hash.Occupied.Static.swift`, `Hash.Occupied.Static+Sequence.Protocol.swift` |
| `Hash.Occupied<Source>.Static<N>.Iterator` | Inline | `Sequence.Iterator.Protocol`, `IteratorProtocol` | `Hash.Occupied.Static.Iterator.swift` |

### Additional Operations (Beyond Canonical)

These operations are specific to `Hash.Table`'s role as an index structure that maps hash values to positions in external storage.

#### Bucket Operations

| Operation | Variant | Access | Source File |
|-----------|---------|--------|-------------|
| `bucket.for(hash:) -> BucketIndex` | Dynamic | public | `Hash.Table+Bucket.swift` (L42-46) |
| `bucket.next(_:) -> BucketIndex` | Dynamic | public | `Hash.Table+Bucket.swift` (L54-57) |
| `bucket.for(hash:) -> BucketIndex` | Static | public | `Hash.Table.Static+Bucket.swift` (L42-44) |
| `bucket.next(_:) -> BucketIndex` | Static | public | `Hash.Table.Static+Bucket.swift` (L50-52) |

#### Position Maintenance

| Operation | Variant | Access | Source File |
|-----------|---------|--------|-------------|
| `positions.decrement(after:)` | Dynamic | public | `Hash.Table+PositionUpdates.swift` (L34-57) |
| `positions.decrement(after:)` | Static | public | `Hash.Table.Static+PositionUpdates.swift` (L43-45) |
| `positions.update(forHash:equals:newPosition:) -> Bool` | Static | public | `Hash.Table.Static+PositionUpdates.swift` (L57-65) |
| `positions.update(atBucket:newPosition:)` | Static | public | `Hash.Table.Static+PositionUpdates.swift` (L76-78) |

#### Copy-on-Write Support

| Operation | Variant | Access | Source File |
|-----------|---------|--------|-------------|
| `mutating func ensureUnique() -> Bool` | Dynamic | public | `Hash.Table+ensureUnique.swift` (L16-29) |

#### Static Helpers / Type-Level

| Item | Access | Source File |
|------|--------|-------------|
| `static func bucketCapacity(for:) -> Index<Bucket>.Count` | public | `Hash.Table.swift` (L132-142) |
| `static func normalize(_:) -> Int` | public | `Hash.Table.swift` (L149-153) |
| `static var empty: Int` | public | `Hash.Table.swift` (L100) |
| `static var deleted: Int` | public | `Hash.Table.swift` (L104) |

#### Conditional Conformances

| Conformance | Variant | Source File |
|-------------|---------|-------------|
| `Copyable where Element: Copyable` | Both | `Hash.Table.swift` (L314, L317) |
| `@unchecked Sendable where Element: Sendable` | Both | `Hash.Table.swift` (L315, L318) |

## Gap Analysis

### Present and Correctly Mapped

| Canonical Operation | Dynamic (`Hash.Table`) | Static (`Hash.Table.Static`) |
|---------------------|:-----:|:------:|
| insert(k, v) | `insert(position:hashValue:equals:)` | `insert(position:hashValue:equals:)` |
| insert unchecked | `insert(__unchecked:position:hashValue:)` | `insert(__unchecked:position:hashValue:)` |
| lookup(k) | `position(forHash:equals:)` | `position(forHash:equals:)` |
| lookup(k) bucket | `bucketIndex(forHash:equals:)` | `bucketIndex(forHash:equals:)` |
| delete(k) | `remove(hashValue:equals:)` | `remove(hashValue:equals:)` |
| delete at bucket | `remove(at:)` | `remove(atBucket:)` |
| delete all | `remove.all(keepingCapacity:)` | `remove.all()` / `clearAll()` |
| iterate (view) | `occupied` property | `occupied` property |
| iterate (forEach) | `forEach.occupied { }` | `forEach.occupied { }`, `forEach.position { }` |
| count | `count` | `count` |
| isEmpty | `isEmpty` | `isEmpty` |
| capacity | `capacity` | `capacity` |
| load_factor (bool) | `shouldGrow` (internal) | `shouldGrow` (public) |
| isFull | -- | `isFull` |

All core ADT operations (insert, lookup, delete, iterate, count, isEmpty) are present on both variants. The API correctly reflects the index-structure design: operations accept `Hash.Value` + equality closure rather than keys directly, and return typed `Index<Element>` positions rather than stored values.

### Missing -- Should Add (Primitives Layer)

#### 1. `contains(hashValue:equals:)` on dynamic `Hash.Table`

**Priority**: Low.
**Rationale**: The static variant provides `contains(hashValue:equals:)` as a convenience over `position(forHash:equals:) != nil`. The dynamic variant lacks this, creating an asymmetry. Consumers must write `table.position(forHash: h, equals: eq) != nil` instead of `table.contains(hashValue: h, equals: eq)`.
**Complexity**: Trivial -- one-line delegation to `position(forHash:equals:)`.
**Recommendation**: Add for API symmetry.

```swift
// Hash.Table+Lookup.swift
@inlinable
public borrowing func contains(
    hashValue: Hash.Value,
    equals: (Index<Element>) -> Bool
) -> Bool {
    position(forHash: hashValue, equals: equals) != nil
}
```

#### 2. `rehash()` on dynamic `Hash.Table`

**Priority**: Medium.
**Rationale**: The static variant provides `rehash()` for tombstone compaction after many deletions. The dynamic variant has `grow()` (which rehashes as a side effect of resizing) but no way to compact tombstones *without* growing. After a sequence of insert-then-remove cycles, occupancy can reach the growth threshold even when count is low, triggering unnecessary growth.
**Complexity**: Moderate -- analogous to `grow()` but allocates a same-size buffer instead of doubling.
**Recommendation**: Add. This is a legitimate hash-table maintenance operation.

```swift
// Hash.Table+Removal.swift (or new file)
@inlinable
public mutating func rehash() {
    // Collect occupied entries, clear, reinsert
    // Same logic as grow() but with same capacity
}
```

#### 3. `isFull` on dynamic `Hash.Table`

**Priority**: Low.
**Rationale**: The static variant exposes `isFull` because it cannot grow. The dynamic variant auto-grows on insert, so `isFull` is less useful. However, it could serve as a diagnostic property. Given that `shouldGrow` is already internal and auto-growth is transparent, this is not needed at the primitives layer.
**Recommendation**: Do not add. Auto-growth makes this unnecessary.

### Missing -- Intentionally Absent (Higher Layer)

#### 1. `load_factor` as a numeric value

**Rationale**: The canonical ADT lists `load_factor` returning a numeric ratio (e.g., 0.7). The current API provides `shouldGrow` (a boolean threshold check) and `occupancy` + `capacity` (the raw components). A computed `loadFactor: Double` property would require floating-point arithmetic and introduce Foundation-like concerns into primitives. The discipline boundary analysis (see `hash-table-discipline-boundary-analysis.md`) explicitly identifies load factor *value* as a consumer concern and load factor *threshold policy* as a hash-table concern.
**Recommendation**: Do not add. Consumers who need the numeric ratio can compute `Double(occupancy) / Double(capacity)` themselves. The primitives layer provides the inputs (`occupancy`, `capacity`) and the policy output (`shouldGrow`).

#### 2. `reserveCapacity(_:)` / explicit growth control

**Rationale**: The dynamic variant grows automatically. Explicit growth control (like C++ `rehash(n)` or `reserve(n)`) would expose buffer-level concerns to consumers. The `init(minimumCapacity:)` initializer serves the pre-allocation use case.
**Recommendation**: Do not add. The initializer handles pre-allocation; auto-growth handles the rest.

#### 3. Key-based API (`subscript[key]`, `updateValue(_:forKey:)`)

**Rationale**: `Hash.Table` is an index structure, not a dictionary. Key-based APIs belong to `Dictionary.Ordered` (foundations layer) or `Set.Ordered`, which compose `Hash.Table` with element storage. The hash table deliberately accepts explicit hash values and equality closures to support `~Copyable` elements that cannot conform to `Hashable`.
**Recommendation**: Do not add. This belongs at Layer 3 (Foundations) or higher.

#### 4. `Equatable` conformance

**Rationale**: Hash tables are not meaningfully compared by bucket contents (which depend on insertion order and tombstone distribution). Semantic equality for the *containers* that use hash tables (e.g., `Set.Ordered`) should compare elements, not the hash table index structure.
**Recommendation**: Do not add. Compare the owning container instead.

#### 5. `positions.update(forHash:equals:newPosition:)` on dynamic `Hash.Table`

**Rationale**: The static variant provides `positions.update(forHash:equals:newPosition:)` and `positions.update(atBucket:newPosition:)` for re-targeting a hash entry. The dynamic variant only provides `positions.decrement(after:)`. The missing update operations would be useful for container-level operations that move elements without removing and reinserting hash entries.
**Recommendation**: Consider adding if consumer demand emerges. Not blocking.

## Symmetric API Comparison

The following table highlights asymmetries between the two variants.

| Operation | Dynamic | Static | Notes |
|-----------|:-------:|:------:|-------|
| `contains(hashValue:equals:)` | **missing** | present | Should add to dynamic |
| `rehash()` | **missing** | present | Should add to dynamic |
| `isFull` | absent | present | Intentional -- dynamic auto-grows |
| `occupancy` | absent (internal `_occupied`) | `occupancy` (public) | Intentional -- dynamic hides internals |
| `shouldGrow` | internal | public | Intentional -- dynamic auto-grows; static exposes for spill detection |
| `forEach.position { }` | absent | present | Could add if demand emerges |
| `eachOccupiedWhile { }` | absent | present (package) | Could add if demand emerges |
| `positions.update(forHash:...)` | absent | present | Could add if demand emerges |
| `positions.update(atBucket:...)` | absent | present | Could add if demand emerges |
| `remove.all(keepingCapacity:)` | present | `remove.all()` (no capacity param) | Intentional -- static has fixed capacity |
| `ensureUnique()` | present | absent | Intentional -- static is value-typed |
| `grow()` | internal | absent | Intentional -- static cannot grow |

Most asymmetries are intentional consequences of the dynamic/static split. The two items that should be addressed are `contains` and `rehash` on the dynamic variant.

## Outcome

**Status**: RECOMMENDATION

### Summary

swift-hash-table-primitives provides **all nine canonical hash table operations** across its two variants, with two minor gaps on the dynamic variant:

1. **`contains`** -- trivial convenience missing from dynamic variant (present on static). Should add for API symmetry.
2. **`rehash`** -- tombstone compaction missing from dynamic variant (present on static). Should add for maintenance completeness.

Beyond the canonical operations, the package provides substantial additional infrastructure appropriate to its role as a primitives-layer index structure:

- **Position maintenance** (`positions.decrement(after:)`, `positions.update(...)`) -- essential for ordered collections that compact on removal
- **Bucket operations** (`bucket.for(hash:)`, `bucket.next(...)`) -- exposed for advanced consumers
- **Copy-on-Write** (`ensureUnique()`) -- essential for value-semantic containers
- **Sequence conformance** (`Sequence.Protocol`, `Swift.Sequence`) on iteration views
- **Type safety** (phantom-typed `Index<Element>`, `Index<Bucket>`, bounded positions)

Operations intentionally absent (key-based API, numeric load factor, explicit growth control, `Equatable`) correctly belong to higher layers in the five-layer architecture.

### Recommended Actions

| Action | Priority | Complexity | Variant |
|--------|----------|------------|---------|
| Add `contains(hashValue:equals:)` to `Hash.Table` | Low | Trivial (1 line) | Dynamic |
| Add `rehash()` to `Hash.Table` | Medium | Moderate (~30 lines) | Dynamic |

## References

- `hash-table-discipline-boundary-analysis.md` -- Detailed layering audit of all public APIs
- `hash-table-storage-buffer-layering.md` -- Storage architecture decisions
- `inline-hash-table.md` -- Design decisions for `Hash.Table.Static`
- `typed-iteration-audit-remediation.md` -- Typed iteration and property audit
- Source: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Sources/`
