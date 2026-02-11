# Typed Iteration Audit Remediation

<!--
---
version: 1.0.0
last_updated: 2026-02-10
status: DECISION
---
-->

## Context

After fixing infinite probe loops at full capacity (commit `6313ef6`), an audit against `/implementation` revealed systematic violations of [IMPL-033] (typed iteration loops), [IMPL-006] (typed stored properties), [IMPL-003] (functor operations), and [PATTERN-018] (Int escape for computation) across 16 files in `Hash Table Primitives`.

During implementation, the `InlineArray[position:]` and `UnsafePointer[position:]` subscripts from `Ordinal Primitives Standard Library Integration` were found to be dead infrastructure — they compiled in their defining module but failed to resolve from any consuming context due to a Swift compiler interaction with `MemberImportVisibility` and subscript parameter labels.

## Question

How should hash table iterator storage access achieve [IMPL-010]-compliant typed subscript access when the boundary overloads (`InlineArray[position:]`, `UnsafePointer[position:]`) don't resolve across module boundaries?

## Analysis

### Root Cause

The subscripts were defined as:
```swift
public subscript<O: Ordinal.`Protocol`>(position: O) -> Element
```

In Swift subscripts, `(position: O)` uses `position` as both external label and internal name. Under `MemberImportVisibility`, the compiler failed to resolve these extension subscripts on stdlib types across module boundaries — reporting "extraneous argument label 'position:'" while matching only the built-in `subscript(_ index: Int)`.

### Resolution

The fix was to separate external label from internal parameter name:
```swift
public subscript<O: Ordinal.`Protocol`>(position position_: O) -> Element
```

This resolved the compiler issue. The `(position position_: O)` form uses `position` as the external label (call sites write `[position: value]`) and `position_` as the internal name. This is a workaround for what appears to be a Swift compiler bug with `MemberImportVisibility` and extension subscripts on stdlib generic types.

### Cascading Impact

Fixing the subscripts caused 40 downstream compilation errors in `swift-bit-vector-primitives`, where `InlineArray` was accessed with `Index<Word>` values (an `Ordinal.Protocol` conformer) without the `position:` label. All 40 sites were updated to use `[position: loc.word]` — a cascading [IMPL-010] improvement.

## Outcome

**Status**: DECISION

### Changes Applied

**Phase 1 — Typed Iteration ([IMPL-033])**: Replaced `for i in 0..<capacity` + per-iteration `__unchecked` construction with `var bucket: BucketIndex = .zero; while bucket < cap { ... bucket += .one }` in:
- `Hash.Table.Static.forEachBucketIndex` (Core)
- `Hash.Table.Static.eachOccupiedWhile` (Core)
- `Hash.Table.forEach.occupied` (Dynamic)
- `Hash.Table.positions.decrement(after:)` (Dynamic)
- `Hash.Table.grow()` (Dynamic)

**Phase 2 — Typed Properties ([PATTERN-018])**: Replaced `Int(bitPattern:)` arithmetic with typed operations:
- `isFull`: `_occupied >= capacity` (pure `Tagged<Bucket, Cardinal>` comparison)
- `shouldGrow`: `_occupied * Scale(10) >= capacity * Scale(7)` using `Affine.Discrete.Ratio<Bucket, Bucket>` for dimensionless scaling

**Phase 3 — Typed Stored Properties ([IMPL-006])**: Converted raw `Int` stored properties to typed equivalents:
- `Hash.Occupied.View._capacity` → `Hash.Table<Source>.BucketIndex.Count`
- `Hash.Occupied.View._count` → `Index<Source>.Count`
- `Hash.Occupied.Static._count` → `Index<Source>.Count`
- Iterator `_index` → `Hash.Table<Source>.BucketIndex`
- Iterator `_capacity` → `Hash.Table<Source>.BucketIndex.Count`

**Phase 4 — Boundary Overloads ([IMPL-010])**: Iterator `next()` uses `[position:]` subscript — `Int(bitPattern:)` lives inside the subscript, not at the call site:
```swift
let hash = _hashes[position: bucket]
```

**Phase 5 — Functor Operations ([IMPL-003])**: Replaced `Index<Bucket>.Count(_count.rawValue)` with `_count.retag(Bucket.self)`.

**Phase 6 — Stdlib Boundary ([IMPL-010])**: `underestimatedCount` returns `Int(bitPattern: _count)` at the `Swift.Sequence` protocol boundary.

### Infrastructure Fix

`Ordinal Primitives Standard Library Integration` subscripts changed from `(position: O)` to `(position position_: O)` to work around `MemberImportVisibility` interaction. This should be tracked as a potential Swift compiler bug.

## References

- `/implementation` skill: [IMPL-033], [IMPL-006], [IMPL-010], [IMPL-003], [PATTERN-018]
- `Ordinal Primitives Standard Library Integration/InlineArray+Ordinal.swift` — boundary subscript
- `Ordinal Primitives Standard Library Integration/UnsafePointer+Ordinal.swift` — boundary subscript
- `Affine Primitives Core/Affine.Discrete.Ratio.swift` — dimensionless scaling
- `Ordinal Primitives/Tagged+Ordinal.swift:129` — cross-type comparison (ordinal < cardinal)
- `Ordinal Primitives Core/Ordinal.Protocol.swift:112` — typed increment (`+= .one`)
