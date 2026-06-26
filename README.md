# Hash Table Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift-primitives/swift-hash-table-primitives/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-primitives/swift-hash-table-primitives/actions/workflows/ci.yml)

`Hash.Table<Element>` — an open-addressed hash table that maps elements to their **typed positions in external storage**, with O(1) average-case lookup. It is the index layer that hashed collections are built on: rather than owning elements, it stores `(hash, position)` pairs where each position is an `Index<Element>` into a separate element array (for example, the backing array of an ordered set). Insertion, lookup, and removal manage those mappings under linear probing.

The element index and the bucket index are distinct phantom types, so a position for one collection cannot be used against another, and a bucket index cannot be confused with an element position — both mismatches are compile-time errors. `Element` may be move-only (`~Copyable`); the table never copies an element, only hashes it. Most code reaches this through a higher-level set or dictionary; depend on it directly when building a custom hashed container over your own storage.

---

## Key Features

- **Index layer, not a container** — maps elements to `Index<Element>` positions in external storage; the elements live wherever you keep them.
- **O(1) average lookup** — open addressing with linear probing.
- **Phantom-typed positions** — element indices and bucket indices are distinct types; cross-collection or bucket/element mix-ups are compile-time errors.
- **Move-only friendly** — `~Copyable` elements are hashed, never copied.

---

## Quick Start

```swift
import Hash_Table_Primitives

// Index positions into an external element store, O(1) average lookup.
var table = Hash.Table<String>(minimumCapacity: 16)

print(table.count)     // 0
print(table.isEmpty)   // true

// `insert` records an element's hash → its Index<String> in your element array;
// `bucket.for(hash:)` / `next(_:)` walk the probe sequence; `remove` clears a mapping.
// Higher-level sets and dictionaries drive these to maintain element ↔ position.
```

---

## Installation

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-hash-table-primitives.git", branch: "main")
]
```

Add a product to your target:

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Hash Table Primitives", package: "swift-hash-table-primitives")
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the corresponding Linux / Windows toolchain).

---

## Architecture

| Product | Contents | When to import |
|---------|----------|----------------|
| `Hash Table Primitives` | Umbrella — `Hash.Table` and its operation surface | Most consumers |
| `Hash Table Primitive` | `Hash.Table<Element>` — the open-addressed index table | Naming the type directly |
| `Hash Indexed Primitive` | The dense-storage indexing support type | Advanced / internal composition |

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS 26         | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | —   | Supported    |

---

## Related Packages

- [`swift-hash-primitives`](https://github.com/swift-primitives/swift-hash-primitives) — the hashing capability elements are keyed by.
- [`swift-set-primitives`](https://github.com/swift-primitives/swift-set-primitives) / [`swift-dictionary-primitives`](https://github.com/swift-primitives/swift-dictionary-primitives) — the hashed collections built on this index layer.
- [`swift-index-primitives`](https://github.com/swift-primitives/swift-index-primitives) — `Index<Element>`, the typed position the table maps to.

---

## Community

<!-- BEGIN: discussion -->
<!-- Discussion thread created at publication. -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
