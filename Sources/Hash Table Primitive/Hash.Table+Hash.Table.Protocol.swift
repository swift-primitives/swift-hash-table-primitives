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

public import Hash_Primitives
public import Index_Primitives

// MARK: - Hash.Table : Hash.Table.Protocol
//
// The dynamic table's position domain is the unbounded `Index<Element>`. The
// existing `position(forHash:equals:)` / `position(forHash:context:equals:)`
// methods (in Hash.Table+Lookup.swift) are the witnesses — this conformance is
// the witness-table marker plus the `Position` binding.

extension Hash.Table: __HashTableProtocol where Element: ~Copyable {
    /// The unbounded position domain — a typed index into external storage.
    public typealias Position = Index<Element>
}
