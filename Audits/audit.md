# Audit: swift-hash-table-primitives

## Legacy — Consolidated 2026-04-08

### From: typed-iteration-audit-remediation.md (2026-02-10)

**Scope**: Systematic audit against `/implementation` skill for [IMPL-033] (typed iteration), [IMPL-006] (typed stored properties), [IMPL-003] (functor operations), [PATTERN-018] (Int escape for computation) across 16 files in Hash Table Primitives. Also discovered and fixed dead boundary overloads in Ordinal Primitives Standard Library Integration.

**Auditor**: Claude | **Status**: DECISION (all items resolved)

**Changes applied across 6 phases**:

| Phase | Requirement | Scope | Status |
|-------|------------|-------|--------|
| 1 — Typed Iteration | [IMPL-033] | 5 methods: forEachBucketIndex, eachOccupiedWhile, forEach.occupied, positions.decrement, grow() | RESOLVED — replaced `for i in 0..<capacity` + per-iteration `__unchecked` with `var bucket: BucketIndex = .zero; while bucket < cap` |
| 2 — Typed Properties | [PATTERN-018] | isFull, shouldGrow | RESOLVED — replaced `Int(bitPattern:)` arithmetic with pure `Tagged<Bucket, Cardinal>` comparison and `Affine.Discrete.Ratio` scaling |
| 3 — Typed Stored Properties | [IMPL-006] | 5 stored properties across Hash.Occupied.View, Hash.Occupied.Static, iterators | RESOLVED — converted raw Int to BucketIndex, BucketIndex.Count, Index<Source>.Count |
| 4 — Boundary Overloads | [IMPL-010] | Iterator next() | RESOLVED — uses `[position:]` subscript; Int(bitPattern:) confined inside the subscript |
| 5 — Functor Operations | [IMPL-003] | Count retag | RESOLVED — replaced `Index<Bucket>.Count(_count.rawValue)` with `_count.retag(Bucket.self)` |
| 6 — Stdlib Boundary | [IMPL-010] | underestimatedCount | RESOLVED — returns `Int(bitPattern: _count)` at Swift.Sequence protocol boundary |

**Infrastructure fix**: `Ordinal Primitives Standard Library Integration` subscripts changed from `(position: O)` to `(position position_: O)` to work around `MemberImportVisibility` interaction with extension subscripts on stdlib generic types. Cascaded to 40 call sites in swift-bit-vector-primitives. Tracked as potential Swift compiler bug.

**Cross-references**: `/implementation` skill [IMPL-033], [IMPL-006], [IMPL-010], [IMPL-003], [PATTERN-018]

---

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-hash-table-primitives.md (2026-03-20)

**Implementation + naming audit**

HIGH=16, MEDIUM=19, LOW=13, INFO=7
Finding IDs: IMPL-002, IMPL-010, IMPL-020, IMPL-024, IMPL-033, IMPL-050, IMPL-052, PATTERN-016, PATTERN-017, PATTERN-021
