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

// MARK: - Index: Hash.Protocol

// Note: The `==` requirement is satisfied by Index+Comparison.Protocol.swift
// which provides `Comparison.Protocol` conformance with identical signature.
// This avoids ambiguous `==` operators.

extension Tagged: @retroactive Hash.`Protocol`
where RawValue == Affine.Discrete.Position, Tag: ~Copyable {
    @inlinable
    public borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
